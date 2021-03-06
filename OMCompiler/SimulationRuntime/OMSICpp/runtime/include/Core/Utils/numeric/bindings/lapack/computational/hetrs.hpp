//
// Copyright (c) 2002--2010
// Toon Knapen, Karl Meerbergen, Kresimir Fresl,
// Thomas Klimpel and Rutger ter Borg
//
// Distributed under the Boost Software License, Version 1.0.
// (See accompanying file LICENSE_1_0.txt or copy at
// http://www.boost.org/LICENSE_1_0.txt)
//
// THIS FILE IS AUTOMATICALLY GENERATED
// PLEASE DO NOT EDIT!
//

#ifndef BOOST_NUMERIC_BINDINGS_LAPACK_COMPUTATIONAL_HETRS_HPP
#define BOOST_NUMERIC_BINDINGS_LAPACK_COMPUTATIONAL_HETRS_HPP

#include <boost/assert.hpp>
#include <Core/Utils/numeric/bindings/begin.hpp>
#include <Core/Utils/numeric/bindings/is_column_major.hpp>
#include <Core/Utils/numeric/bindings/is_mutable.hpp>
#include <Core/Utils/numeric/bindings/remove_imaginary.hpp>
#include <Core/Utils/numeric/bindings/size.hpp>
#include <Core/Utils/numeric/bindings/stride.hpp>
#include <Core/Utils/numeric/bindings/uplo_tag.hpp>
#include <Core/Utils/numeric/bindings/value_type.hpp>
#include <boost/static_assert.hpp>
#include <boost/type_traits/is_same.hpp>
#include <boost/type_traits/remove_const.hpp>

//
// The LAPACK-backend for hetrs is the netlib-compatible backend.
//
#include <Core/Utils/numeric/bindings/lapack/detail/lapack.h>
#include <Core/Utils/numeric/bindings/lapack/detail/lapack_option.hpp>

namespace boost
{
    namespace numeric
    {
        namespace bindings
        {
            namespace lapack
            {
                //
                // The detail namespace contains value-type-overloaded functions that
                // dispatch to the appropriate back-end LAPACK-routine.
                //
                namespace detail
                {
                    //
                    // Overloaded function for dispatching to
                    // * netlib-compatible LAPACK backend (the default), and
                    // * float value-type.
                    //
                    template <typename UpLo>
                    inline std::ptrdiff_t hetrs(const UpLo, const fortran_int_t n,
                                                const fortran_int_t nrhs, const float* a, const fortran_int_t lda,
                                                const fortran_int_t* ipiv, float* b, const fortran_int_t ldb)
                    {
                        fortran_int_t info(0);
                        LAPACK_SSYTRS(&lapack_option<UpLo>::value, &n, &nrhs, a, &lda, ipiv, b,
                                      &ldb, &info);
                        return info;
                    }

                    //
                    // Overloaded function for dispatching to
                    // * netlib-compatible LAPACK backend (the default), and
                    // * double value-type.
                    //
                    template <typename UpLo>
                    inline std::ptrdiff_t hetrs(const UpLo, const fortran_int_t n,
                                                const fortran_int_t nrhs, const double* a, const fortran_int_t lda,
                                                const fortran_int_t* ipiv, double* b, const fortran_int_t ldb)
                    {
                        fortran_int_t info(0);
                        LAPACK_DSYTRS(&lapack_option<UpLo>::value, &n, &nrhs, a, &lda, ipiv, b,
                                      &ldb, &info);
                        return info;
                    }

                    //
                    // Overloaded function for dispatching to
                    // * netlib-compatible LAPACK backend (the default), and
                    // * complex<float> value-type.
                    //
                    template <typename UpLo>
                    inline std::ptrdiff_t hetrs(const UpLo, const fortran_int_t n,
                                                const fortran_int_t nrhs, const std::complex<float>* a,
                                                const fortran_int_t lda, const fortran_int_t* ipiv,
                                                std::complex<float>* b, const fortran_int_t ldb)
                    {
                        fortran_int_t info(0);
                        LAPACK_CHETRS(&lapack_option<UpLo>::value, &n, &nrhs, a, &lda, ipiv, b,
                                      &ldb, &info);
                        return info;
                    }

                    //
                    // Overloaded function for dispatching to
                    // * netlib-compatible LAPACK backend (the default), and
                    // * complex<double> value-type.
                    //
                    template <typename UpLo>
                    inline std::ptrdiff_t hetrs(const UpLo, const fortran_int_t n,
                                                const fortran_int_t nrhs, const std::complex<double>* a,
                                                const fortran_int_t lda, const fortran_int_t* ipiv,
                                                std::complex<double>* b, const fortran_int_t ldb)
                    {
                        fortran_int_t info(0);
                        LAPACK_ZHETRS(&lapack_option<UpLo>::value, &n, &nrhs, a, &lda, ipiv, b,
                                      &ldb, &info);
                        return info;
                    }
                } // namespace detail

                //
                // Value-type based template class. Use this class if you need a type
                // for dispatching to hetrs.
                //
                template <typename Value>
                struct hetrs_impl
                {
                    typedef Value value_type;
                    typedef typename remove_imaginary<Value>::type real_type;

                    //
                    // Static member function, that
                    // * Deduces the required arguments for dispatching to LAPACK, and
                    // * Asserts that most arguments make sense.
                    //
                    template <typename MatrixA, typename VectorIPIV, typename MatrixB>
                    static std::ptrdiff_t invoke(const MatrixA& a, const VectorIPIV& ipiv,
                                                 MatrixB& b)
                    {
                        namespace bindings = ::boost::numeric::bindings;
                        typedef typename result_of::uplo_tag<MatrixA>::type uplo;
                        BOOST_STATIC_ASSERT((bindings::is_column_major<MatrixA>::value));
                        BOOST_STATIC_ASSERT((bindings::is_column_major<MatrixB>::value));
                        BOOST_STATIC_ASSERT((boost::is_same<typename remove_const<
                                                                typename bindings::value_type<MatrixA>::type>::type,
                                                            typename remove_const<typename bindings::value_type<
                                                                MatrixB>::type>::type>::value));
                        BOOST_STATIC_ASSERT((bindings::is_mutable<MatrixB>::value));
                        BOOST_ASSERT(bindings::size(ipiv) >= bindings::size_column(a));
                        BOOST_ASSERT(bindings::size_column(a) >= 0);
                        BOOST_ASSERT(bindings::size_column(b) >= 0);
                        BOOST_ASSERT(bindings::size_minor(a) == 1 ||
                            bindings::stride_minor(a) == 1);
                        BOOST_ASSERT(bindings::size_minor(b) == 1 ||
                            bindings::stride_minor(b) == 1);
                        BOOST_ASSERT(bindings::stride_major(a) >= std::max<std::ptrdiff_t>(1,
                                                                                           bindings::size_column(a)));
                        BOOST_ASSERT(bindings::stride_major(b) >= std::max<std::ptrdiff_t>(1,
                                                                                           bindings::size_column(a)));
                        return detail::hetrs(uplo(), bindings::size_column(a),
                                             bindings::size_column(b), bindings::begin_value(a),
                                             bindings::stride_major(a), bindings::begin_value(ipiv),
                                             bindings::begin_value(b), bindings::stride_major(b));
                    }
                };


                //
                // Functions for direct use. These functions are overloaded for temporaries,
                // so that wrapped types can still be passed and used for write-access. In
                // addition, if applicable, they are overloaded for user-defined workspaces.
                // Calls to these functions are passed to the hetrs_impl classes. In the
                // documentation, most overloads are collapsed to avoid a large number of
                // prototypes which are very similar.
                //

                //
                // Overloaded function for hetrs. Its overload differs for
                //
                template <typename MatrixA, typename VectorIPIV, typename MatrixB>
                inline std::ptrdiff_t hetrs(const MatrixA& a, const VectorIPIV& ipiv,
                                            MatrixB& b)
                {
                    return hetrs_impl<typename bindings::value_type<
                        MatrixA>::type>::invoke(a, ipiv, b);
                }
            } // namespace lapack
        } // namespace bindings
    } // namespace numeric
} // namespace boost

#endif
