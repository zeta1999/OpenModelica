/*
 * This file is part of OpenModelica.
 *
 * Copyright (c) 1998-2014, Open Source Modelica Consortium (OSMC),
 * c/o Linköpings universitet, Department of Computer and Information Science,
 * SE-58183 Linköping, Sweden.
 *
 * All rights reserved.
 *
 * THIS PROGRAM IS PROVIDED UNDER THE TERMS OF GPL VERSION 3 LICENSE OR
 * THIS OSMC PUBLIC LICENSE (OSMC-PL) VERSION 1.2.
 * ANY USE, REPRODUCTION OR DISTRIBUTION OF THIS PROGRAM CONSTITUTES
 * RECIPIENT'S ACCEPTANCE OF THE OSMC PUBLIC LICENSE OR THE GPL VERSION 3,
 * ACCORDING TO RECIPIENTS CHOICE.
 *
 * The OpenModelica software and the Open Source Modelica
 * Consortium (OSMC) Public License (OSMC-PL) are obtained
 * from OSMC, either from the above address,
 * from the URLs: http://www.ida.liu.se/projects/OpenModelica or
 * http://www.openmodelica.org, and in the OpenModelica distribution.
 * GNU version 3 is obtained from: http://www.gnu.org/copyleft/gpl.html.
 *
 * This program is distributed WITHOUT ANY WARRANTY; without
 * even the implied warranty of  MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE, EXCEPT AS EXPRESSLY SET FORTH
 * IN THE BY RECIPIENT SELECTED SUBSIDIARY LICENSE CONDITIONS OF OSMC-PL.
 *
 * See the full OSMC Public License conditions for more details.
 *
 */

encapsulated uniontype NFExpandExp
  import Expression = NFExpression;

protected
  import RangeIterator = NFRangeIterator;
  import ExpressionIterator = NFExpressionIterator;
  import Subscript = NFSubscript;
  import Type = NFType;
  import NFCall.Call;
  import Dimension = NFDimension;
  import ComponentRef = NFComponentRef;
  import NFFunction.Function;
  import Operator = NFOperator;
  import Ceval = NFCeval;
  import NFInstNode.InstNode;
  import SimplifyExp = NFSimplifyExp;
  import MetaModelica.Dangerous.*;

public
  function expand
    input output Expression exp;
          output Boolean expanded;
  algorithm
    (exp, expanded) := match exp
      local
        list<Expression> expl;

      case Expression.CREF(ty = Type.ARRAY()) then expandCref(exp);

      case Expression.ARRAY(ty = Type.ARRAY(dimensions = _ :: _ :: {}))
        algorithm
          (expl, expanded) := expandList(exp.elements);
          exp.elements := expl;
        then
          (exp, expanded);

      case Expression.ARRAY() then (exp, true);
      case Expression.RANGE() then expandRange(exp);
      case Expression.CALL() then expandCall(exp.call, exp);
      case Expression.SIZE() then expandSize(exp);
      case Expression.BINARY() then expandBinary(exp, exp.operator);
      case Expression.UNARY() then expandUnary(exp.exp, exp.operator);
      case Expression.LBINARY() then expandLogicalBinary(exp);
      case Expression.LUNARY() then expandLogicalUnary(exp.exp, exp.operator);
      case Expression.CAST() then expandCast(exp.exp, exp.ty);
      else expandGeneric(exp);
    end match;
  end expand;

  function expandList
    "Expands a list of Expressions. If abortOnFailure is true the function will
     stop if it fails to expand an element and the original list will be
     returned unchanged. If abortOnFailure is false it will instead continue and
     try to expand the whole list. In both cases the output 'expanded' indicates
     whether the whole list could be expanded or not."
    input list<Expression> expl;
    input Boolean abortOnFailure = true;
    output list<Expression> outExpl = {};
    output Boolean expanded = true;
  protected
    Boolean res;
  algorithm
    for exp in expl loop
      (exp, res) := expand(exp);
      expanded := res and expanded;

      if not res and abortOnFailure then
        outExpl := expl;
        return;
      end if;

      outExpl := exp :: outExpl;
    end for;

    outExpl := listReverseInPlace(outExpl);
  end expandList;

  function expandCref
    input Expression crefExp;
    output Expression arrayExp;
    output Boolean expanded;
  protected
    list<list<list<Subscript>>> subs;
  algorithm
    (arrayExp, expanded) := match crefExp
      case Expression.CREF(cref = ComponentRef.CREF())
        guard Type.hasKnownSize(crefExp.ty)
        algorithm
          subs := expandCref2(crefExp.cref);

          if listEmpty(subs) then
            arrayExp := Expression.ARRAY(Type.ARRAY(Type.arrayElementType(crefExp.ty), {Dimension.fromInteger(0)}), {});
          else
            arrayExp := expandCref3(subs, crefExp.cref, Type.arrayElementType(crefExp.ty));
          end if;
        then
          (arrayExp, true);

      else (crefExp, false);
    end match;
  end expandCref;

  function expandCref2
    input ComponentRef cref;
    input output list<list<list<Subscript>>> subs = {};
  protected
    list<list<Subscript>> cr_subs = {};
    list<Dimension> dims;

    import NFComponentRef.Origin;
  algorithm
    subs := match cref
      case ComponentRef.CREF(origin = Origin.CREF)
        algorithm
          dims := Type.arrayDims(cref.ty);
          cr_subs := Subscript.expandList(cref.subscripts, dims);
        then
          if listEmpty(cr_subs) and not listEmpty(dims) then
            {} else expandCref2(cref.restCref, cr_subs :: subs);

      else subs;
    end match;
  end expandCref2;

  function expandCref3
    input list<list<list<Subscript>>> subs;
    input ComponentRef cref;
    input Type crefType;
    input list<list<Subscript>> accum = {};
    output Expression arrayExp;
  algorithm
    arrayExp := match subs
      case {} then Expression.CREF(crefType, ComponentRef.setSubscriptsList(accum, cref));
      else expandCref4(listHead(subs), {}, accum, listRest(subs), cref, crefType);
    end match;
  end expandCref3;

  function expandCref4
    input list<list<Subscript>> subs;
    input list<Subscript> comb = {};
    input list<list<Subscript>> accum = {};
    input list<list<list<Subscript>>> restSubs;
    input ComponentRef cref;
    input Type crefType;
    output Expression arrayExp;
  protected
    list<Expression> expl = {};
    Type arr_ty;
  algorithm
    arrayExp := match subs
      case {} then expandCref3(restSubs, cref, crefType, listReverse(comb) :: accum);
      else
        algorithm
          expl := list(expandCref4(listRest(subs), sub :: comb, accum, restSubs, cref, crefType)
            for sub in listHead(subs));
          arr_ty := Type.liftArrayLeft(Expression.typeOf(listHead(expl)), Dimension.fromExpList(expl));
        then
          Expression.ARRAY(arr_ty, expl);
    end match;
  end expandCref4;

  function expandRange
    input Expression exp;
    output Expression outExp;
    output Boolean expanded;
  protected
    RangeIterator range_iter;
    Type ty;
  algorithm
    Expression.RANGE(ty = ty) := exp;
    expanded := Type.hasKnownSize(ty);

    if expanded then
      range_iter := RangeIterator.fromExp(exp);
      outExp := Expression.ARRAY(ty, RangeIterator.toList(range_iter));
    else
      outExp := exp;
    end if;
  end expandRange;

  function expandCall
    input Call call;
    input Expression exp;
    output Expression outExp;
    output Boolean expanded;
  algorithm
    (outExp, expanded) := matchcontinue call
      case Call.TYPED_CALL()
        guard Function.isBuiltin(call.fn) and not Function.isImpure(call.fn)
        then expandBuiltinCall(call.fn, call.arguments, call);

      case Call.TYPED_MAP_CALL()
        then expandReduction(call.exp, call.ty, call.iters);

      else expandGeneric(exp);
    end matchcontinue;
  end expandCall;

  function expandBuiltinCall
    input Function fn;
    input list<Expression> args;
    input Call call;
    output Expression outExp;
    output Boolean expanded;
  protected
    Absyn.Path fn_path = Function.nameConsiderBuiltin(fn);
  algorithm
    (outExp, expanded) := match Absyn.pathFirstIdent(fn_path)
      case "cat" then expandBuiltinCat(args, call);
      case "promote" then expandBuiltinPromote(args);
    end match;
  end expandBuiltinCall;

  function expandBuiltinCat
    input list<Expression> args;
    input Call call;
    output Expression exp;
    output Boolean expanded;
  protected
    list<Expression> expl = {};
  algorithm
    (expl, expanded) := expandList(listRest(args));

    if expanded then
      // This relies on the fact that Ceval.evalBuiltinCat doesn't actually do any
      // actual constant evaluation, and works on non-constant arrays too as long
      // as they're expanded.
      exp := Ceval.evalBuiltinCat(listHead(args), expl, Ceval.EvalTarget.IGNORE_ERRORS());
    else
      exp := expandGeneric(Expression.CALL(call));
    end if;
  end expandBuiltinCat;

  function expandBuiltinPromote
    input list<Expression> args;
    output Expression exp;
    output Boolean expanded;
  protected
    Integer n;
    Expression eexp, nexp;
  algorithm
    eexp :: nexp :: {} := args;
    Expression.INTEGER(value = n) := nexp;
    (eexp, expanded) := expand(eexp);
    exp := Expression.promote(eexp, Expression.typeOf(eexp), n);
  end expandBuiltinPromote;

  function expandReduction
    input Expression exp;
    input Type ty;
    input list<tuple<InstNode, Expression>> iterators;
    output Expression result;
    output Boolean expanded = true;
  protected
    Expression e = exp, range;
    InstNode node;
    list<Expression> ranges = {}, expl;
    Mutable<Expression> iter;
    list<Mutable<Expression>> iters = {};
  algorithm
    for i in iterators loop
      (node, range) := i;
      iter := Mutable.create(Expression.INTEGER(0));
      e := Expression.replaceIterator(e, node, Expression.MUTABLE(iter));
      iters := iter :: iters;
      (range, true) := expand(range);
      ranges := range :: ranges;
    end for;

    result := expandReduction2(e, ty, ranges, iters);
  end expandReduction;

  function expandReduction2
    input Expression exp;
    input Type ty;
    input list<Expression> ranges;
    input list<Mutable<Expression>> iterators;
    output Expression result;
  protected
    Expression range;
    list<Expression> ranges_rest, expl = {};
    Mutable<Expression> iter;
    list<Mutable<Expression>> iters_rest;
    ExpressionIterator range_iter;
    Expression value;
    Type el_ty;
  algorithm
    if listEmpty(ranges) then
      // Normally it wouldn't be the expansion's task to simplify expressions,
      // but we make an exception here since the generated expressions contain
      // MUTABLE expressions that we need to get rid of. Also, expansion of
      // reductions is often done during the scalarization phase, after the
      // simplification phase, so they wouldn't otherwise be simplified.
      result := expand(SimplifyExp.simplify(exp));
    else
      range :: ranges_rest := ranges;
      iter :: iters_rest := iterators;
      range_iter := ExpressionIterator.fromExp(range);
      el_ty := Type.unliftArray(ty);

      while ExpressionIterator.hasNext(range_iter) loop
        (range_iter, value) := ExpressionIterator.next(range_iter);
        Mutable.update(iter, value);
        expl := expandReduction2(exp, el_ty, ranges_rest, iters_rest) :: expl;
      end while;

      result := Expression.ARRAY(ty, listReverseInPlace(expl));
    end if;
  end expandReduction2;

  function expandSize
    input Expression exp;
    output Expression outExp;
    output Boolean expanded = true;
  algorithm
    outExp := match exp
      local
        Integer dims;
        Expression e;
        Type ty;
        list<Expression> expl;

      case Expression.SIZE(exp = e, dimIndex = NONE())
        algorithm
          ty := Expression.typeOf(e);
          dims := Type.dimensionCount(ty);
          expl := list(Expression.SIZE(e, SOME(Expression.INTEGER(i))) for i in 1:dims);
        then
          Expression.ARRAY(Type.ARRAY(ty, {Dimension.fromInteger(dims)}), expl);

      // Size with an index is scalar, and thus already maximally expanded.
      else exp;
    end match;
  end expandSize;

  function expandBinary
    input Expression exp;
    input Operator op;
    output Expression outExp;
    output Boolean expanded;

    import NFOperator.Op;
  algorithm
    (outExp, expanded) := match op.op
      case Op.ADD_SCALAR_ARRAY  then expandBinaryScalarArray(exp, Op.ADD);
      case Op.ADD_ARRAY_SCALAR  then expandBinaryArrayScalar(exp, Op.ADD);
      case Op.SUB_SCALAR_ARRAY  then expandBinaryScalarArray(exp, Op.SUB);
      case Op.SUB_ARRAY_SCALAR  then expandBinaryArrayScalar(exp, Op.SUB);
      case Op.MUL_SCALAR_ARRAY  then expandBinaryScalarArray(exp, Op.MUL);
      case Op.MUL_ARRAY_SCALAR  then expandBinaryArrayScalar(exp, Op.MUL);
      case Op.MUL_VECTOR_MATRIX then expandBinaryVectorMatrix(exp);
      case Op.MUL_MATRIX_VECTOR then expandBinaryMatrixVector(exp);
      case Op.SCALAR_PRODUCT    then expandBinaryDotProduct(exp);
      case Op.MATRIX_PRODUCT    then expandBinaryMatrixProduct(exp);
      case Op.DIV_SCALAR_ARRAY  then expandBinaryScalarArray(exp, Op.DIV);
      case Op.DIV_ARRAY_SCALAR  then expandBinaryArrayScalar(exp, Op.DIV);
      case Op.POW_SCALAR_ARRAY  then expandBinaryScalarArray(exp, Op.POW);
      case Op.POW_ARRAY_SCALAR  then expandBinaryArrayScalar(exp, Op.POW);
      case Op.POW_MATRIX        then expandBinaryPowMatrix(exp);
      else                           expandBinaryElementWise(exp);
    end match;

    if not expanded then
      outExp := exp;
    end if;
  end expandBinary;

  function expandBinaryElementWise
    input Expression exp;
    output Expression outExp;
    output Boolean expanded;
  protected
    Expression exp1, exp2;
    Operator op;
  algorithm
    Expression.BINARY(exp1 = exp1, operator = op, exp2 = exp2) := exp;
    (exp1, expanded) := expand(exp1);

    if expanded then
      (exp2, expanded) := expand(exp2);
    end if;

    if expanded then
      outExp := expandBinaryElementWise2(exp1, op, exp2, makeBinaryOp);
    else
      outExp := exp;
    end if;
  end expandBinaryElementWise;

  function expandBinaryElementWise2
    input Expression exp1;
    input Operator op;
    input Expression exp2;
    input MakeFn func;
    output Expression exp;

    partial function MakeFn
      input Expression exp1;
      input Operator op;
      input Expression exp2;
      output Expression exp;
    end MakeFn;
  protected
    list<Expression> expl1, expl2, expl;
    Type ty;
    Operator eop;
  algorithm
    expl1 := Expression.arrayElements(exp1);
    expl2 := Expression.arrayElements(exp2);
    ty := Operator.typeOf(op);
    eop := Operator.setType(Type.unliftArray(ty), op);

    if Type.dimensionCount(ty) > 1 then
      expl := list(expandBinaryElementWise2(e1, eop, e2, func) threaded for e1 in expl1, e2 in expl2);
    else
      expl := list(func(e1, eop, e2) threaded for e1 in expl1, e2 in expl2);
    end if;

    exp := Expression.ARRAY(ty, expl);
  end expandBinaryElementWise2;

  function expandBinaryScalarArray
    input Expression exp;
    input NFOperator.Op scalarOp;
    output Expression outExp;
    output Boolean expanded;
  protected
    Expression exp1, exp2;
    list<Expression> expl;
    Operator op;
  algorithm
    Expression.BINARY(exp1 = exp1, operator = op, exp2 = exp2) := exp;
    (exp2, expanded) := expand(exp2);

    if expanded then
      op := Operator.OPERATOR(Type.arrayElementType(Operator.typeOf(op)), scalarOp);
      outExp := Expression.mapArrayElements(exp2, function makeBinaryOp(op = op, exp1 = exp1));
    else
      outExp := exp;
    end if;
  end expandBinaryScalarArray;

  function makeScalarArrayBinary_traverser
    input Expression exp1;
    input Operator op;
    input Expression exp2;
    output Expression exp;
  algorithm
    exp := match exp2
      case Expression.ARRAY() then exp2;
      else makeBinaryOp(exp1, op, exp2);
    end match;
  end makeScalarArrayBinary_traverser;

  function expandBinaryArrayScalar
    input Expression exp;
    input NFOperator.Op scalarOp;
    output Expression outExp;
    output Boolean expanded;
  protected
    Expression exp1, exp2;
    list<Expression> expl;
    Operator op;
  algorithm
    Expression.BINARY(exp1 = exp1, operator = op, exp2 = exp2) := exp;
    (exp1, expanded) := expand(exp1);

    if expanded then
      op := Operator.OPERATOR(Type.arrayElementType(Operator.typeOf(op)), scalarOp);
      outExp := Expression.mapArrayElements(exp1, function makeBinaryOp(op = op, exp2 = exp2));
    else
      outExp := exp;
    end if;
  end expandBinaryArrayScalar;

  function expandBinaryVectorMatrix
    "Expands a vector*matrix expression, c[m] = a[n] * b[n, m]."
    input Expression exp;
    output Expression outExp;
    output Boolean expanded;
  protected
    Expression exp1, exp2;
    list<Expression> expl;
    Type ty;
    Dimension m;
  algorithm
    Expression.BINARY(exp1 = exp1, exp2 = exp2) := exp;
    (exp2, expanded) := expand(exp2);

    if expanded then
      Expression.ARRAY(Type.ARRAY(ty, {m, _}), expl) := Expression.transposeArray(exp2);
      ty := Type.ARRAY(ty, {m});

      if listEmpty(expl) then
        outExp := Expression.makeZero(ty);
      else
        (exp1, expanded) := expand(exp1);

        if expanded then
          // c[i] = a * b[:, i] for i in 1:m
          expl := list(makeScalarProduct(exp1, e2) for e2 in expl);
          outExp := Expression.ARRAY(ty, expl);
        else
          outExp := exp;
        end if;
      end if;
    else
      outExp := exp;
    end if;
  end expandBinaryVectorMatrix;

  function expandBinaryMatrixVector
    "Expands a matrix*vector expression, c[n] = a[n, m] * b[m]."
    input Expression exp;
    output Expression outExp;
    output Boolean expanded;
  protected
    Expression exp1, exp2;
    list<Expression> expl;
    Type ty;
    Dimension n;
  algorithm
    Expression.BINARY(exp1 = exp1, exp2 = exp2) := exp;
    (exp1, expanded) := expand(exp1);

    if expanded then
      Expression.ARRAY(Type.ARRAY(ty, {n, _}), expl) := exp1;
      ty := Type.ARRAY(ty, {n});

      if listEmpty(expl) then
        outExp := Expression.makeZero(ty);
      else
        (exp2, expanded) := expand(exp2);

        if expanded then
          // c[i] = a[i, :] * b for i in 1:n
          expl := list(makeScalarProduct(e1, exp2) for e1 in expl);
          outExp := Expression.ARRAY(ty, expl);
        else
          outExp := exp;
        end if;
      end if;
    else
      outExp := exp;
    end if;
  end expandBinaryMatrixVector;

  function expandBinaryDotProduct
    "Expands a vector*vector expression, c = a[n] * b[n]."
    input Expression exp;
    output Expression outExp;
    output Boolean expanded;
  protected
    Expression exp1, exp2;
  algorithm
    Expression.BINARY(exp1 = exp1, exp2 = exp2) := exp;
    (exp1, expanded) := expand(exp1);

    if expanded then
      (exp2, expanded) := expand(exp2);
    end if;

    if expanded then
      outExp := makeScalarProduct(exp1, exp2);
    else
      outExp := exp;
    end if;
  end expandBinaryDotProduct;

  function makeScalarProduct
    input Expression exp1;
    input Expression exp2;
    output Expression exp;
  protected
    list<Expression> expl1, expl2;
    Type ty, tyUnlift;
    Operator mul_op, add_op;
  algorithm
    Expression.ARRAY(ty, expl1) := exp1;
    Expression.ARRAY( _, expl2) := exp2;
    tyUnlift := Type.unliftArray(ty);

    if listEmpty(expl1) then
      // Scalar product of two empty arrays. The result is defined in the spec
      // by sum, so we return 0 since that's the default value of sum.
      exp := Expression.makeZero(tyUnlift);
    end if;
    mul_op := Operator.makeMul(tyUnlift);
    add_op := Operator.makeAdd(tyUnlift);
    expl1 := list(makeBinaryOp(e1, mul_op, e2) threaded for e1 in expl1, e2 in expl2);
    exp := List.reduce(expl1, function makeBinaryOp(op = add_op));
  end makeScalarProduct;

  function expandBinaryMatrixProduct
    "Expands a matrix*matrix expression, c[n, p] = a[n, m] * b[m, p]."
    input Expression exp;
    output Expression outExp;
    output Boolean expanded;
  protected
    Expression exp1, exp2;
  algorithm
    Expression.BINARY(exp1 = exp1, exp2 = exp2) := exp;
    (exp1, expanded) := expand(exp1);

    if expanded then
      (exp2, expanded) := expand(exp2);
    end if;

    if expanded then
      outExp := makeBinaryMatrixProduct(exp1, exp2);
    else
      outExp := exp;
    end if;
  end expandBinaryMatrixProduct;

  function makeBinaryMatrixProduct
    input Expression exp1;
    input Expression exp2;
    output Expression exp;
  protected
    list<Expression> expl1, expl2;
    Type ty, row_ty, mat_ty;
    Dimension n, p;
  algorithm
    Expression.ARRAY(Type.ARRAY(ty, {n, _}), expl1) := exp1;
    // Transpose the second matrix. This makes it easier to do the multiplication,
    // since we can do row-row multiplications instead of row-column.
    Expression.ARRAY(Type.ARRAY(dimensions = {p, _}), expl2) := Expression.transposeArray(exp2);
    mat_ty := Type.ARRAY(ty, {n, p});

    if listEmpty(expl2) then
      // If any of the matrices' dimensions are zero, the result will be a matrix
      // of zeroes (the default value of sum). Only expl2 needs to be checked here,
      // the normal case can handle expl1 being empty.
      exp := Expression.makeZero(mat_ty);
    else
      // c[i, j] = a[i, :] * b[:, j] for i in 1:n, j in 1:p.
      row_ty := Type.ARRAY(ty, {p});
      expl1 := list(Expression.ARRAY(row_ty, makeBinaryMatrixProduct2(e, expl2)) for e in expl1);
      exp := Expression.ARRAY(mat_ty, expl1);
    end if;
  end makeBinaryMatrixProduct;

  function makeBinaryMatrixProduct2
    input Expression row;
    input list<Expression> matrix;
    output list<Expression> outRow;
  algorithm
    outRow := list(makeScalarProduct(row, e) for e in matrix);
  end makeBinaryMatrixProduct2;

  function expandBinaryPowMatrix
    input Expression exp;
    output Expression outExp;
    output Boolean expanded;
  protected
    Expression exp1, exp2;
    Operator op;
    Integer n;
  algorithm
    Expression.BINARY(exp1 = exp1, operator = op, exp2 = exp2) := exp;

    (outExp, expanded) := match exp2
      // a ^ 0 = identity(size(a, 1))
      case Expression.INTEGER(0)
        algorithm
          n := Dimension.size(listHead(Type.arrayDims(Operator.typeOf(op))));
        then
          (Expression.makeIdentityMatrix(n, Type.REAL()), true);

      // a ^ n where n is a literal value.
      case Expression.INTEGER(n)
        algorithm
          (exp1, expanded) := expand(exp1);

          if expanded then
            outExp := expandBinaryPowMatrix2(exp1, n);
          end if;
        then
          (outExp, expanded);

      // a ^ n where n is unknown, subscript the whole expression.
      else expandGeneric(exp);
    end match;
  end expandBinaryPowMatrix;

  function expandBinaryPowMatrix2
    input Expression matrix;
    input Integer n;
    output Expression exp;
  algorithm
    exp := match n
      // A^1 = A
      case 1 then matrix;
      // A^2 = A * A
      case 2 then makeBinaryMatrixProduct(matrix, matrix);

      // A^n = A^m * A^m where n = 2*m
      case _ guard intMod(n, 2) == 0
        algorithm
          exp := expandBinaryPowMatrix2(matrix, intDiv(n, 2));
        then
          makeBinaryMatrixProduct(exp, exp);

      // A^n = A * A^(n-1)
      else
        algorithm
          exp := expandBinaryPowMatrix2(matrix, n - 1);
        then
          makeBinaryMatrixProduct(matrix, exp);

    end match;
  end expandBinaryPowMatrix2;

  function makeBinaryOp
    input Expression exp1;
    input Operator op;
    input Expression exp2;
    output Expression exp;
  algorithm
    if Expression.isScalarLiteral(exp1) and Expression.isScalarLiteral(exp2) then
      exp := Ceval.evalBinaryOp(exp1, op, exp2);
    else
      exp := Expression.BINARY(exp1, op, exp2);
    end if;
  end makeBinaryOp;

  function expandUnary
    input Expression exp;
    input Operator op;
    output Expression outExp;
    output Boolean expanded;
  protected
    Operator scalar_op;
  algorithm
    (outExp, expanded) := expand(exp);
    scalar_op := Operator.scalarize(op);

    if expanded then
      outExp := Expression.mapArrayElements(outExp, function makeUnaryOp(op = scalar_op));
    end if;
  end expandUnary;

  function makeUnaryOp
    input Expression exp1;
    input Operator op;
    output Expression exp = Expression.UNARY(op, exp1);
  end makeUnaryOp;

  function expandLogicalBinary
    input Expression exp;
    output Expression outExp;
    output Boolean expanded;
  protected
    Expression exp1, exp2;
    Operator op;
  algorithm
    Expression.LBINARY(exp1 = exp1, operator = op, exp2 = exp2) := exp;
    (exp1, expanded) := expand(exp1);

    if expanded then
      (exp2, expanded) := expand(exp2);
    end if;

    if expanded then
      outExp := expandBinaryElementWise2(exp1, op, exp2, makeLBinaryOp);
    else
      outExp := exp;
    end if;
  end expandLogicalBinary;

  function makeLBinaryOp
    input Expression exp1;
    input Operator op;
    input Expression exp2;
    output Expression exp;
  algorithm
    if Expression.isScalarLiteral(exp1) and Expression.isScalarLiteral(exp2) then
      exp := Ceval.evalLogicBinaryOp(exp1, op, exp2);
    else
      exp := Expression.LBINARY(exp1, op, exp2);
    end if;
  end makeLBinaryOp;

  function expandLogicalUnary
    input Expression exp;
    input Operator op;
    output Expression outExp;
    output Boolean expanded;
  protected
    Operator scalar_op;
  algorithm
    (outExp, expanded) := expand(exp);
    scalar_op := Operator.scalarize(op);

    if expanded then
      outExp := Expression.mapArrayElements(outExp, function makeLogicalUnaryOp(op = scalar_op));
    else
      outExp := exp;
    end if;
  end expandLogicalUnary;

  function makeLogicalUnaryOp
    input Expression exp1;
    input Operator op;
    output Expression exp = Expression.LUNARY(op, exp1);
  end makeLogicalUnaryOp;

  function expandCast
    input Expression exp;
    input Type ty;
    output Expression outExp;
    output Boolean expanded;
  protected
    Type ety = Type.arrayElementType(ty);
  algorithm
    (outExp, expanded) := expand(exp);

    if expanded then
      outExp := Expression.mapArrayElements(outExp, function Expression.typeCast(castTy = ety));
    else
      outExp := exp;
    end if;
  end expandCast;

  function expandGeneric
    input Expression exp;
    output Expression outExp;
    output Boolean expanded;
  protected
    Type ty;
    list<Dimension> dims;
    list<list<Expression>> subs;
  algorithm
    ty := Expression.typeOf(exp);

    if Type.isArray(ty) then
      expanded := Type.hasKnownSize(ty);

      if expanded then
        dims := Type.arrayDims(ty);
        subs := list(RangeIterator.toList(RangeIterator.fromDim(d)) for d in dims);
        outExp := expandGeneric2(subs, exp, ty);
      else
        outExp := exp;
      end if;
    else
      outExp := exp;
      expanded := true;
    end if;
  end expandGeneric;

  function expandGeneric2
    input list<list<Expression>> subs;
    input Expression exp;
    input Type ty;
    input list<Expression> accum = {};
    output Expression outExp;
  protected
    Type t;
    list<Expression> sub, expl;
    list<list<Expression>> rest_subs;
  algorithm
    outExp := match subs
      case sub :: rest_subs
        algorithm
          t := Type.unliftArray(ty);
          expl := list(expandGeneric2(rest_subs, exp, t, s :: accum) for s in sub);
        then
          Expression.ARRAY(ty, expl);

      case {}
        algorithm
          outExp := exp;
          for s in listReverse(accum) loop
            outExp := Expression.applyIndexSubscript(s, outExp);
          end for;
        then
          outExp;

    end match;
  end expandGeneric2;

annotation(__OpenModelica_Interface="frontend");
end NFExpandExp;
