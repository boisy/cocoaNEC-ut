/* last change:  pgm   8 nov 2000    1:04 pm */
/* program somnec( input,output,tape21 ) */

/* program to generate nec interpolation grids for fields due to */
/* ground.  field components are computed by numerical evaluation */
/* of modified sommerfeld integrals. */

/* somnec2d is a long double precision version of somnec for use with */
/* nec2d.  --- cocoaNEC 0.44 changed to double instead of long double. */
/* an alternate version ( somnec2sd ) is also provided in which */
/* computation is in single precision but the output file is written */
/* in long double precision for use with nec2d.  somnec2sd runs about twic */
/* as fast as the full long double precision somnec2d.  the difference */
/* between nec2d results using a for021 file from this code rather */
/* than from somnec2sd was insignficant in the cases tested. */

/* changes made by j bergervoet, 31-5-95: */
/* parameter 0. --> 0.d0 in calling of routine test */
/* status of output files set to 'unknown' */

#include "nec2c.h"
#import <MacTypes.h>        //  for Boolean type

typedef struct {
	double a1[25], a2[25], a3[25], a4[25] ;
	double psi ;
	int m[101] ;
	int besselInit, hankelInit ;
} SomnecVars ;

typedef struct {
	//  keys
	double epr ;
	double sig ;
	double fmhz ;
	//  values
	complex double ar1[11*10*4], ar2[17*5*4], ar3[9*8*4] ;
	complex double epscf ;
} SomnecCache ;


static SomnecVars bessVars ;

static void test( double f1r, double f2r, double *tr, double f1i, double f2i, double *ti, double dmin ) ;

static void initBessel( SomnecVars *b ) ;
static void bessel( SomnecVars *b, complex double z, complex double *j0, complex double *j0p ) ;

static void evlua( complex double *erv, complex double *ezv, complex double *erh, complex double *eph ) ;
static void gshank( complex double start, complex double dela, complex double *sum, int nans, complex double *seed, int ibk, complex double bk, complex double delb ) ;

static void initHankel( SomnecVars *h ) ;
static void hankel( SomnecVars *h, complex double z, complex double *h0, complex double *h0p ) ;

static void lambda( double t, complex double *xlam, complex double *dxlam ) ;
static void rom1( int n, complex double *sum, int nx ) ;
static void saoa( SomnecVars *b, double t, complex double *ans ) ;

/*common  /ggrid/ */
//  v0.44
int nxa[3] = { 11, 17, 9 } ;
int nya[3] = { 10, 5, 8 } ;
double dxa[3] = { 0.02, 0.05, 0.1 } ;
double dya[3] = { 0.1745329252, 0.0872664626, 0.1745329252 } ;
double xsa[3] = { 0.0, 0.2, 0.2 } ;
double ysa[3] = { 0.0, 0.0, 0.3490658504 } ;
complex double ar1[11*10*4], ar2[17*5*4], ar3[9*8*4] ;
complex double epscf ;

static int jh ;
static double ck2, ck2sq, tkmag, tsmag, ck1r, zph, rho ;
static complex double ct1, ct2, ct3, ck1, ck1sq, cksm, a, b ;

#define	CACHESIZE 16
static Boolean cacheInitialized = false ;
static int nextCacheIndex ;
static SomnecCache cache[CACHESIZE] ;

/*-----------------------------------------------------------------------*/

void initSomnec()
{
	int i ;
	SomnecCache *c ;
	
	if ( !cacheInitialized ) {
		for ( i = 0; i < CACHESIZE; i++ ) {
			c = &cache[i] ;
			c->epr = c->sig = c->fmhz = 0.0 ;
			bzero( c->ar1, sizeof( complex double )*11*10*4 ) ;
			bzero( c->ar2, sizeof( complex double )*17*5*4 ) ;
			bzero( c->ar3, sizeof( complex double )*9*8*4 ) ;
			c->epscf = ( 0.0+0.0fj ) ;
			nextCacheIndex = 0 ;
		}
		cacheInitialized = true ;
	}
}

static Boolean isCached( double epr, double sig, double fmhz )
{
	int i ;
	SomnecCache *c ;
	
	for ( i = 0; i < CACHESIZE; i++ ) {
		c = &cache[i] ;
		if ( c->epr == epr && c->sig == sig && c->fmhz == fmhz ) {
			memcpy( ar1, c->ar1, sizeof( complex double )*11*10*4 ) ;
			memcpy( ar2, c->ar2, sizeof( complex double )*17*5*4 ) ;
			memcpy( ar3, c->ar3, sizeof( complex double )*9*8*4 ) ;
			epscf = c->epscf ;
			return true ;
		}
	}
	return false ;
}

static void setCache( double epr, double sig, double fmhz )
{
	SomnecCache *c ;
	
	c = &cache[ nextCacheIndex % CACHESIZE ] ;
	
	c->epr = epr ;
	c->sig = sig ;
	c->fmhz = fmhz ;
	memcpy( c->ar1, ar1, sizeof( complex double )*11*10*4 ) ;
	memcpy( c->ar2, ar2, sizeof( complex double )*17*5*4 ) ;
	memcpy( c->ar3, ar3, sizeof( complex double )*9*8*4 ) ;
	c->epscf = epscf ;
	
	nextCacheIndex = ( nextCacheIndex + 1 ) % CACHESIZE ;
}

/* This is the "main" of somnec */
//  v0.44
void somnec( double epr, double sig, double fmhz )
{
	int k, nth, ith, irs, ir, nr ;
	double wlam, dr, dth, r, rk, thet, tfac1, tfac2 ;
	complex double erv, ezv, erh, eph, cl1, cl2, con ;
	double tim, tst ;
	
    dth = 0 ;
	//  no need to recompute if values for the input parameters are cached
	if ( isCached( epr, sig, fmhz ) ) return ;
	
	//  force functions to initialize
	bessVars.besselInit = bessVars.hankelInit = 0 ;

	//  ggrid
	nxa[0] = 11 ;
	nxa[1] = 17 ;
	nxa[2] = 9  ;
	nya[0] = 10 ;
	nya[1] = 5 ;
	nya[2] = 8 ;
	dxa[0] = 0.02 ;
	dxa[1] = 0.05 ;
	dxa[2] = 0.1 ;
	dya[0] = dya[2] = 0.1745329252 ;
	dya[1] = 0.0872664626 ;
	xsa[0] = 0.0 ;
	xsa[1] = xsa[2] = 0.2 ;
	ysa[0] = ysa[1] = 0.0 ;
	ysa[2] = 0.3490658504 ;
	
	if ( sig >= 0.0 ) {
		wlam = CVEL/fmhz ;
		epscf = cmplx( epr,-sig*wlam*59.96 ) ;
	}
	else epscf = cmplx( epr,sig ) ;

	secnds( &tst ) ;
	ck2 = TP ;
	ck2sq = ck2*ck2 ;

	/* sommerfeld integral evaluation uses exp( -jwt ), nec uses exp( +jwt ), */
	/* hence need conjg( epscf ).  conjugate of fields occurs in subroutine */
	/* evlua. */

	ck1sq = ck2sq*conj( epscf ) ;
	ck1 = csqrt( ck1sq ) ;
	ck1r = creal( ck1 ) ;
	tkmag = 100.*cabs( ck1 ) ;
	tsmag = 100.*ck1*conj( ck1 ) ;
	cksm = ck2sq/( ck1sq+ck2sq ) ;
	ct1 = .5*( ck1sq-ck2sq ) ;
	erv = ck1sq*ck1sq ;
	ezv = ck2sq*ck2sq ;
	ct2 = .125*( erv-ezv ) ;
	erv *= ck1sq ;
	ezv *= ck2sq ;
	ct3 = .0625*( erv-ezv ) ;

	/* loop over 3 grid regions */
	for ( k = 0 ; k < 3 ; k++ ) {
		nr = nxa[k] ;
		nth = nya[k] ;
		dr = dxa[k] ;
		dth = dya[k] ;
		r = xsa[k]-dr ;
		irs = 1 ;
		if ( k == 0 ) {
			r = xsa[k] ;
			irs = 2 ;
		}

		/*  loop over r.  ( r=sqrt( rho**2 + ( z+h )**2 ) ) */
		for ( ir = irs-1 ; ir < nr ; ir++ ) {
			r += dr ;
			thet = ysa[k]-dth ;
			/* loop over theta.  ( theta=atan( ( z+h )/rho ) ) */
			for ( ith = 0 ; ith < nth ; ith++ ) {
				thet += dth ;
				rho = r*cos( thet ) ;
				zph = r*sin( thet ) ;
				if ( rho < 1.e-7 ) rho = 1.e-8 ;
				if ( zph < 1.e-7 ) zph = 0. ;

				evlua( &erv, &ezv, &erh, &eph ) ;

				rk = ck2*r ;
				con = -CONST1*r/cmplx( cos( rk ),-sin( rk ) ) ;

				switch( k ) {
				case 0:
					ar1[ir+ith*11+  0] = erv*con ;
					ar1[ir+ith*11+110] = ezv*con ;
					ar1[ir+ith*11+220] = erh*con ;
					ar1[ir+ith*11+330] = eph*con ;
					break ;

				case 1:
					ar2[ir+ith*17+  0] = erv*con ;
					ar2[ir+ith*17+ 85] = ezv*con ;
					ar2[ir+ith*17+170] = erh*con ;
					ar2[ir+ith*17+255] = eph*con ;
					break ;

				case 2:
					ar3[ir+ith*9+  0] = erv*con ;
					ar3[ir+ith*9+ 72] = ezv*con ;
					ar3[ir+ith*9+144] = erh*con ;
					ar3[ir+ith*9+216] = eph*con ;

				} /* switch( k ) */

			} /* for ( ith = 0 ; ith < nth ; ith++ ) */

		} /* for ( ir = irs-1 ; ir < nr ; ir++ ; ) */

	} /* for ( k = 0 ; k < 3 ; k++ ; ) */

	/* fill grid 1 for r equal to zero. */
	cl2 = -CONST4*( epscf-1.0 )/( epscf+1.0 ) ;
	cl1 = cl2/( epscf+1.0 ) ;
	ezv = epscf*cl1 ;
	thet = -dth ;
	nth = nya[0] ;
 
	for ( ith = 0 ; ith < nth ; ith++ ) {
		thet += dth ;
		if ( ( ith+1 ) != nth ) {
			tfac2 = cos( thet ) ;
			tfac1 = ( 1.-sin( thet ) )/tfac2 ;
			tfac2 = tfac1/tfac2 ;
			erv = epscf*cl1*tfac1 ;
			erh = cl1*( tfac2-1.0 )+cl2 ;
			eph = cl1*tfac2-cl2 ;
		}
		else {
			erv = 0. ;
			erh = cl2-.5*cl1 ;
			eph = -erh ;
		}
		ar1[0+ith*11+  0] = erv ;
		ar1[0+ith*11+110] = ezv ;
		ar1[0+ith*11+220] = erh ;
		ar1[0+ith*11+330] = eph ;
	}

	secnds( &tim ) ;
	tim -= tst ;
	
	setCache( epr, sig, fmhz ) ;
}

/*-----------------------------------------------------------------------*/

/* bessel evaluates the zero-order bessel function */
/* and its derivative for complex argument z. */

static void initBessel( SomnecVars *g )
{
	int i, k, index = 0 ;
	double tst ;
	
	for ( k = 1 ; k <= 25 ; k++ ) {
		i = k-1 ;
		g->a1[i] = -0.25/( k*k ) ;
		g->a2[i] = 1.0/( k+1.0 ) ;
	}

	for ( i = 1 ; i <= 101 ; i++ ) {
		tst = 1.0 ;
		for ( k = 0 ; k < 24 ; k++ ) {
			index = k ;
			tst *= -i * g->a1[k] ;
			if ( tst < 1.0e-6 ) break ;
		}
		g->m[i-1] = index+1 ;
	}
	g->besselInit = 1 ;
}

static void bessel( SomnecVars *g, complex double z, complex double *j0, complex double *j0p )
{
	int k, ib, iz, miz ;
	double zms ;
	complex double p0z, p1z, q0z, q1z, zi, zi2, zk, cz, sz, j0x = 0, j0px = 0 ;

	if ( g->besselInit == 0 ) initBessel( g ) ;
	
	zms = z*conj( z ) ;
	if ( zms <= 1.e-12 ) {
		*j0 = CPLX_10 ;
		*j0p = -0.5*z ;
		return ;
	}

	ib = 0 ;
	if ( zms <= 37.21 ) {
		if ( zms > 36.0 ) ib=1 ;

		/* series expansion */
		iz = zms ;
		miz = g->m[iz] ;
		*j0 = CPLX_10 ;
		*j0p = *j0 ;
		zk = *j0 ;
		zi = z*z ;

		for ( k = 0 ; k < miz ; k++ ) {
			zk *= g->a1[k]*zi ;
			*j0 += zk ;
			*j0p += g->a2[k]*zk ;
		}
		*j0p *= -0.5*z ;

		if ( ib == 0 ) return ;

		j0x = *j0 ;
		j0px = *j0p ;
	}

	/* asymptotic expansion */
	zi = 1./z ;
	zi2 = zi*zi ;
	p0z = 1.0 + ( P20*zi2-P10 )*zi2 ;
	p1z = 1.0 + ( P11-P21*zi2 )*zi2 ;
	q0z = ( Q20*zi2-Q10 )*zi ;
	q1z = ( Q11-Q21*zi2 )*zi ;
	zk = cexp( CPLX_01*( z-POF ) ) ;
	zi2 = 1.0/zk ;
	cz = 0.5*( zk+zi2 ) ;
	sz = CPLX_01 * 0.5 * ( zi2-zk ) ;
	zk = C3*csqrt( zi ) ;
	*j0 = zk*( p0z*cz-q0z*sz ) ;
	*j0p = -zk*( p1z*sz+q1z*cz ) ;

	if ( ib == 0 ) return ;

	zms = cos( ( sqrt( zms ) - 6.0 )*PI10 ) ;
	*j0 = 0.5*( j0x*( 1.+zms ) + *j0*( 1.-zms ) ) ;
	*j0p = 0.5*( j0px*( 1.+zms ) + *j0p*( 1.-zms ) ) ;
}

/*-----------------------------------------------------------------------*/

/* evlua controls the integration contour in the complex */
/* lambda plane for evaluation of the sommerfeld integrals */
static void evlua( complex double *erv, complex double *ezv, complex double *erh, complex double *eph )
{
  int i, jump ;
  double del, slope, rmis ;
  static complex double cp1, cp2, cp3, bk, delta, delta2 ;
  static complex double sum[6] ;
  static complex double ans[6] ;

	bk = 0.0 ;
	
  del = zph ;
  if ( rho > del )
    del = rho ;

  if ( zph >= 2.*rho )
  {
    /* bessel function form of sommerfeld integrals */
    jh = 0 ;
    a = CPLX_00 ;
    del = 1./del ;

    if ( del > tkmag )
    {
      b = cmplx( .1*tkmag,-.1*tkmag ) ;
      rom1( 6,sum,2 ) ;
      a = b ;
      b = cmplx( del,-del ) ;
      rom1 ( 6,ans,2 ) ;
      for ( i = 0 ; i < 6 ; i++ )
	sum[i] += ans[i] ;
    }
    else
    {
      b = cmplx( del,-del ) ;
      rom1( 6,sum,2 ) ;
    }

    delta = PTP*del ;
    gshank( b,delta,ans,6,sum,0,b,b ) ;
    ans[5] *= ck1 ;

    /* conjugate since nec uses exp( +jwt ) */
    *erv = conj( ck1sq*ans[2] ) ;
    *ezv = conj( ck1sq*( ans[1]+ck2sq*ans[4] ) ) ;
    *erh = conj( ck2sq*( ans[0]+ans[5] ) ) ;
    *eph = -conj( ck2sq*( ans[3]+ans[5] ) ) ;

    return ;

  } /* if ( zph >= 2.*rho ) */

  /* hankel function form of sommerfeld integrals */
  jh = 1 ;
  cp1 = cmplx( 0.0, 0.4*ck2 ) ;
  cp2 = cmplx( 0.6*ck2, -0.2*ck2 ) ;
  cp3 = cmplx( 1.02*ck2, -0.2*ck2 ) ;
  a = cp1 ;
  b = cp2 ;
  rom1( 6, sum, 2 ) ;
  a = cp2 ;
  b = cp3 ;
  rom1( 6, ans, 2 ) ;

  for ( i = 0 ; i < 6 ; i++ ) sum[i] = -( sum[i]+ans[i] ) ;

  /* path from imaginary axis to -infinity */
  if ( zph > .001*rho )
    slope = rho/zph ;
  else
    slope = 1000. ;

  del = PTP/del ;
  delta = cmplx( -1.0,slope )*del/sqrt( 1.+slope*slope ) ;
  delta2 = -conj( delta ) ;
  
  gshank( cp1,delta,ans,6,sum,0,bk,bk ) ;

  rmis = rho*( creal( ck1 )-ck2 ) ;

  jump = FALSE ;
  if ( ( rmis >= 2.*ck2 ) && ( rho >= 1.e-10 ) )
  {
    if ( zph >= 1.e-10 )
    {
      bk = cmplx( -zph,rho )*( ck1-cp3 ) ;
      rmis = -creal( bk )/fabs( cimag( bk ) ) ;
      if ( rmis > 4.*rho/zph )
	jump = TRUE ;
    }

    if ( ! jump )
    {
      /* integrate up between branch cuts, then to + infinity */
      cp1 = ck1-( .1+.2fj ) ;
      cp2 = cp1+.2 ;
      bk = cmplx( 0.,del ) ;
      gshank( cp1,bk,sum,6,ans,0,bk,bk ) ;
      a = cp1 ;
      b = cp2 ;
      rom1( 6,ans,1 ) ;
      for ( i = 0 ; i < 6 ; i++ )
	ans[i] -= sum[i] ;

      gshank( cp3,bk,sum,6,ans,0,bk,bk ) ;
      gshank( cp2,delta2,ans,6,sum,0,bk,bk ) ;
    }

    jump = TRUE ;

  } /* if ( ( rmis >= 2.*ck2 ) || ( rho >= 1.e-10 ) ) */
  else
    jump = FALSE ;

  if ( ! jump )
  {
    /* integrate below branch points, then to + infinity */
    for ( i = 0 ; i < 6 ; i++ ) sum[i] = -ans[i] ;

    rmis = creal( ck1 )*1.01 ;
    if ( ( ck2+1.0 ) > rmis )
      rmis = ck2+1. ;

    bk = cmplx( rmis,.99*cimag( ck1 ) ) ;
    delta = bk-cp3 ;
    delta *= del/cabs( delta ) ;
    gshank( cp3,delta,ans,6,sum,1,bk,delta2 ) ;

  } /* if ( ! jump ) */

  ans[5] *= ck1 ;

  /* conjugate since nec uses exp( +jwt ) */
  *erv = conj( ck1sq*ans[2] ) ;
  *ezv = conj( ck1sq*( ans[1]+ck2sq*ans[4] ) ) ;
  *erh = conj( ck2sq*( ans[0]+ans[5] ) ) ;
  *eph = -conj( ck2sq*( ans[3]+ans[5] ) ) ;

  return ;
}

/*-----------------------------------------------------------------------*/

/* gshank integrates the 6 sommerfeld integrals from start to */
/* infinity ( until convergence ) in lambda.  at the break point, bk, */
/* the step increment may be changed from dela to delb.  shank's */
/* algorithm to accelerate convergence of a slowly converging series */
/* is used */
static void gshank( complex double start, complex double dela, complex double *sum,
    int nans, complex double *seed, int ibk, complex double bk, complex double delb )
{
  int ibx, j, i, jm, intx, inx, brk = 0 ;
  static double rbk, amg, den, denm ;
  complex double a1, a2, as1, as2, del, aa ;
  complex double q1[6][20], q2[6][20], ans1[6], ans2[6] ;

  rbk = creal( bk ) ;
  del = dela ;
  if ( ibk == 0 )
    ibx = 1 ;
  else
    ibx = 0 ;

  for ( i = 0 ; i < nans ; i++ )
    ans2[i] = seed[i] ;

  b = start ;
  for ( intx = 1 ; intx <= MAXH ; intx++ )
  {
    inx = intx-1 ;
    a = b ;
    b += del ;

    if ( ( ibx == 0 ) && ( creal( b ) >= rbk ) )
    {
      /* hit break point.  reset seed and start over. */
      ibx = 1 ;
      b = bk ;
      del = delb ;
      rom1( nans,sum,2 ) ;
      if ( ibx != 2 )
      {
	for ( i = 0 ; i < nans ; i++ )
	  ans2[i] += sum[i] ;
	intx = 0 ;
	continue ;
      }

      for ( i = 0 ; i < nans ; i++ )
	ans2[i] = ans1[i]+sum[i] ;
      intx = 0 ;
      continue ;

    } /* if ( ( ibx == 0 ) && ( creal( b ) >= rbk ) ) */

    rom1( nans,sum,2 ) ;
    for ( i = 0 ; i < nans ; i++ )
      ans1[i] = ans2[i]+sum[i] ;
    a = b ;
    b += del ;

    if ( ( ibx == 0 ) && ( creal( b ) >= rbk ) )
    {
      /* hit break point.  reset seed and start over. */
      ibx = 2 ;
      b = bk ;
      del = delb ;
      rom1( nans,sum,2 ) ;
      if ( ibx != 2 )
      {
	for ( i = 0 ; i < nans ; i++ )
	  ans2[i] += sum[i] ;
	intx = 0 ;
	continue ;
      }

      for ( i = 0 ; i < nans ; i++ )
	ans2[i] = ans1[i]+sum[i] ;
      intx = 0 ;
      continue ;

    } /* if ( ( ibx == 0 ) && ( creal( b ) >= rbk ) ) */

    rom1( nans,sum,2 ) ;
    for ( i = 0 ; i < nans ; i++ )
      ans2[i] = ans1[i]+sum[i] ;

    den = 0. ;
    for ( i = 0 ; i < nans ; i++ )
    {
      as1 = ans1[i] ;
      as2 = ans2[i] ;

      if ( intx >= 2 )
      {
	for ( j = 1 ; j < intx ; j++ )
	{
	  jm = j-1 ;
	  aa = q2[i][jm] ;
	  a1 = q1[i][jm]+as1-2.*aa ;

	  if ( ( creal( a1 ) != 0.0 ) || ( cimag( a1 ) != 0.0 ) )
	  {
	    a2 = aa-q1[i][jm] ;
	    a1 = q1[i][jm]-a2*a2/a1 ;
	  }
	  else
	    a1 = q1[i][jm] ;

	  a2 = aa+as2-2.*as1 ;
	  if ( ( creal( a2 ) != 0.0 ) || ( cimag( a2 ) != 0.0 ) )
	    a2 = aa-( as1-aa )*( as1-aa )/a2 ;
	  else
	    a2 = aa ;

	  q1[i][jm] = as1 ;
	  q2[i][jm] = as2 ;
	  as1 = a1 ;
	  as2 = a2 ;

	} /* for ( j = 1 ; i < intx ; i++ ) */

      } /* if ( intx >= 2 ) */

      q1[i][intx-1] = as1 ;
      q2[i][intx-1] = as2 ;
      amg = fabs( creal( as2 ) )+fabs( cimag( as2 ) ) ;
      if ( amg > den )
	den = amg ;

    } /* for ( i = 0 ; i < nans ; i++ ) */

    denm = 1.e-3*den*CRIT ;
    jm = intx-3 ;
    if ( jm < 1 )
      jm = 1 ;

    for ( j = jm-1 ; j < intx ; j++ )
    {
      brk = FALSE ;
      for ( i = 0 ; i < nans ; i++ )
      {
	a1 = q2[i][j] ;
	den = ( fabs( creal( a1 ) )+fabs( cimag( a1 ) ) )*CRIT ;
	if ( den < denm )
	  den = denm ;
	a1 = q1[i][j]-a1 ;
	amg = fabs( creal( a1 )+fabs( cimag( a1 ) ) ) ;
	if ( amg > den )
	{
	  brk = TRUE ;
	  break ;
	}

      } /* for ( i = 0 ; i < nans ; i++ ) */

      if ( brk ) break ;

    } /* for ( j = jm-1 ; j < intx ; j++ ) */

    if ( ! brk )
    {
      for ( i = 0 ; i < nans ; i++ )
	sum[i] = .5*( q1[i][inx]+q2[i][inx] ) ;
      return ;
    }

  } /* for ( intx = 1 ; intx <= maxh ; intx++ ) */

  /* No convergence */
  abort_on_error( -6 ) ;
}

/*-----------------------------------------------------------------------*/

static void initHankel( SomnecVars *g ) 
{
	int i, k, index ;
	double tst ;
	
    g->psi = -GAMMA ;
    for ( k = 1 ; k <= 25 ; k++ ) {
		i = k-1 ;
		g->a1[i] = -.25/( k*k ) ;
		g->a2[i] = 1.0/( k+1.0 ) ;
		g->psi += 1.0/k ;
		g->a3[i] = 2.0 * g->psi ;
		g->a4[i] = ( 2.0*g->psi + 1.0/( k+1.0 ) ) / ( k+1.0 ) ;
    }

    for ( i = 1 ; i <= 101 ; i++ ) {
		tst = 1.0 ;
        index = 0 ;
		for ( k = 0 ; k < 24 ; k++ ) {
			index = k ;
			tst *= -i * g->a1[k] ;
			if ( ( tst * g->a3[k] ) < 1.e-6 ) break ;
		}
		g->m[i-1] = index+1 ;
    }
	g->hankelInit = 1 ;
}

/* hankel evaluates hankel function of the first kind,   */
/* order zero, and its derivative for complex argument z */
static void hankel( SomnecVars *g, complex double z, complex double *h0, complex double *h0p )
{
	int k, ib, iz, miz ;
	double zms ;
	complex double clogz, j0, j0p, p0z, p1z, q0z, q1z, y0 = 0, y0p = 0, zi, zi2, zk ;

	if ( g->hankelInit == 0 ) initHankel( g ) ;

	zms = z*conj( z ) ;
	if ( zms == 0.0 ) abort_on_error( -7 ) ;

	ib = 0 ;
	if ( zms <= 16.81 ) {
		if ( zms > 16.0 ) ib = 1 ;

		/* series expansion */
		iz = zms ;
		miz = g->m[iz] ;
		j0 = CPLX_10 ;
		j0p = j0 ;
		y0 = CPLX_00 ;
		y0p = y0 ;
		zk = j0 ;
		zi = z*z ;

    for ( k = 0 ; k < miz ; k++ )
    {
      zk *= g->a1[k]*zi ;
      j0 += zk ;
      j0p += g->a2[k]*zk ;
      y0 += g->a3[k]*zk ;
      y0p += g->a4[k]*zk ;
    }

    j0p *= -0.5*z ;
    clogz = clog( 0.5*z ) ;
    y0 = ( 2.0*j0*clogz-y0 )/PI+C2 ;
    y0p = ( 2./z+2.*j0p*clogz+.5*y0p*z )/PI+C1*z ;
    *h0 = j0+CPLX_01*y0 ;
    *h0p = j0p+CPLX_01*y0p ;

    if ( ib == 0 )
      return ;

    y0 = *h0 ;
    y0p = *h0p ;

  } /* if ( zms <= 16.81 ) */

  /* asymptotic expansion */
  zi = 1./z ;
  zi2 = zi*zi ;
  p0z = 1.+( P20*zi2-P10 )*zi2 ;
  p1z = 1.+( P11-P21*zi2 )*zi2 ;
  q0z = ( Q20*zi2-Q10 )*zi ;
  q1z = ( Q11-Q21*zi2 )*zi ;
  zk = cexp( CPLX_01*( z-POF ) )*csqrt( zi )*C3 ;
  *h0 = zk*( p0z+CPLX_01*q0z ) ;
  *h0p = CPLX_01*zk*( p1z+CPLX_01*q1z ) ;

  if ( ib == 0 )
    return ;

  zms = cos( ( sqrt( zms )-4.0 )*31.41592654 ) ;
  *h0 = .5*( y0*( 1.+zms )+ *h0*( 1.-zms ) ) ;
  *h0p = .5*( y0p*( 1.+zms )+ *h0p*( 1.-zms ) ) ;

  return ;
}

/*-----------------------------------------------------------------------*/

/* compute integration parameter xlam=lambda from parameter t. */
static void lambda( double t, complex double *xlam, complex double *dxlam )
{
  *dxlam = b-a ;
  *xlam = a+*dxlam*t ;
  return ;
}

/*-----------------------------------------------------------------------*/

/* rom1 integrates the 6 sommerfeld integrals from a to b in lambda. */
/* the method of variable interval width romberg integration is used. */
static void rom1( int n, complex double *sum, int nx )
{
	int jump, lstep, nogo, i, ns, nt ;
	static double z, ze, s, ep, zend, dz = 0., dzot = 0., tr, ti ;
	static complex double t00, t11, t02 ;
	static complex double g1[6], g2[6], g3[6], g4[6], g5[6], t01[6], t10[6], t20[6] ;

	lstep = 0 ;
	z = 0.0 ; 
	ze = 1.0 ;
	s = 1.0 ;
	ep = s/( 1.e4*NM ) ;
	zend = ze-ep ;
	for ( i = 0 ; i < n ; i++ ) sum[i] = CPLX_00 ;
	ns = nx ;
	nt = 0 ;
	saoa( &bessVars, z, g1 ) ;

	jump = FALSE ;
	
	while( TRUE ) {
		if ( ! jump ) {
			dz = s/ns ;
			if ( ( z+dz ) > ze ) {
				dz = ze-z ;
				if ( dz <= ep ) return ;
			}
			dzot = dz*.5 ;
			saoa( &bessVars, z+dzot, g3 ) ;
			saoa( &bessVars, z+dz, g5 ) ;
		} /* if ( ! jump ) */

		nogo = FALSE ;
		for ( i = 0 ; i < n ; i++ ) {
			t00 = ( g1[i]+g5[i] )*dzot ;
			t01[i] = ( t00+dz*g3[i] )*.5 ;
			t10[i] = ( 4.*t01[i]-t00 )/3. ;
			/* test convergence of 3 point romberg result */
			test( creal( t01[i] ), creal( t10[i] ), &tr, cimag( t01[i] ), cimag( t10[i] ), &ti, 0. ) ;
			if ( ( tr > CRIT ) || ( ti > CRIT ) ) nogo = TRUE ;
		}

		if ( !nogo ) {
			for ( i = 0 ; i < n ; i++ ) sum[i] += t10[i] ;

			nt += 2 ;
			z += dz ;
			if ( z > zend ) return ;

			for ( i = 0 ; i < n ; i++ ) g1[i] = g5[i] ;

			if ( ( nt >= NTS ) && ( ns > nx ) ) {
				ns = ns/2 ;
				nt = 1 ;
			}

			jump = FALSE ;
			continue ;
		} /* if ( ! nogo ) */

		saoa( &bessVars, z+dz*0.25, g2 ) ;
		saoa( &bessVars, z+dz*0.75, g4 ) ;
		nogo = FALSE ;
		
		for ( i = 0 ; i < n ; i++ ) {
			t02 = ( t01[i]+dzot*( g2[i]+g4[i] ) )*.5 ;
			t11 = ( 4.*t02-t01[i] )/3. ;
			t20[i] = ( 16.*t11-t10[i] )/15. ;
			/* test convergence of 5 point romberg result */
			test( creal( t11 ), creal( t20[i] ), &tr, cimag( t11 ), cimag( t20[i] ), &ti, 0. ) ;
			if ( ( tr > CRIT ) || ( ti > CRIT ) ) nogo = TRUE ;
		}

		if ( !nogo ) {
			for ( i = 0 ; i < n ; i++ ) sum[i] += t20[i] ;
			nt++ ;
			z += dz ;
			if ( z > zend ) return ;

			for ( i = 0 ; i < n ; i++ ) g1[i] = g5[i] ;

			if ( ( nt >= NTS ) && ( ns > nx ) ) {
				ns = ns/2 ;
				nt = 1 ;
			}
			jump = FALSE ;
			continue ;
		} /* if ( ! nogo ) */

		nt = 0 ;
		if ( ns < NM ) {
			ns *= 2 ;
			dz = s/ns ;
			dzot = dz*.5 ;

			for ( i = 0 ; i < n ; i++ ) {
				g5[i] = g3[i] ;
				g3[i] = g2[i] ;
			}
			jump = TRUE ;
			continue ;
		} /* if ( ns < nm ) */

		if ( !lstep ) {
		  lstep = TRUE ;
		  lambda( z, &t00, &t11 ) ;
		}

		for ( i = 0 ; i < n ; i++ ) sum[i] += t20[i] ;

		nt++ ;
		z += dz ;
		if ( z > zend ) return ;

		for ( i = 0 ; i < n ; i++ ) g1[i] = g5[i] ;

		if ( ( nt >= NTS ) && ( ns > nx ) ) {
		  ns /= 2 ;
		  nt = 1 ;
		}
		jump = FALSE ;

	} /* while( TRUE ) */
}

/*-----------------------------------------------------------------------*/

/* saoa computes the integrand for each of the 6 sommerfeld */
/* integrals for source and observer above ground */
static void saoa( SomnecVars *g, double t, complex double *ans )
{
	double xlr, sign ;
	static complex double xl, dxl, cgam1, cgam2, b0, b0p, com, dgam, den1, den2 ;

	lambda( t, &xl, &dxl ) ;
	if ( jh == 0 ) {
		/* bessel function form */
		bessel( g, xl*rho, &b0, &b0p ) ;
		b0  *= 2. ;
		b0p *= 2. ;
		cgam1 = csqrt( xl*xl-ck1sq ) ;
		cgam2 = csqrt( xl*xl-ck2sq ) ;
		if ( creal( cgam1 ) == 0.0 ) cgam1 = cmplx( 0.0, -fabs( cimag( cgam1 ) ) ) ;
		if ( creal( cgam2 ) == 0.0 ) cgam2 = cmplx( 0.0, -fabs( cimag( cgam2 ) ) ) ;
	}
	else {
		/* hankel function form */
		hankel( g, xl*rho, &b0, &b0p ) ;
		com = xl-ck1 ;
		cgam1 = csqrt( xl+ck1 )*csqrt( com ) ;
		if ( creal( com ) < 0. && cimag( com ) >= 0.0 ) cgam1 = -cgam1 ;
		com = xl-ck2 ;
		cgam2 = csqrt( xl+ck2 )*csqrt( com ) ;
		if ( creal( com ) < 0. && cimag( com ) >= 0.0 ) cgam2 = -cgam2 ;
	}

	xlr = xl*conj( xl ) ;
	if ( xlr >= tsmag ) {
		if ( cimag( xl ) >= 0.0 ) {
			xlr = creal( xl ) ;
			if ( xlr >= ck2 ) {
				if ( xlr <= ck1r ) dgam = cgam2 - cgam1 ;
				else {
					sign = 1. ;
					dgam = 1./( xl*xl ) ;
					dgam = sign*( ( ct3*dgam+ct2 )*dgam+ct1 )/xl ;
				}
			}
			else {
				sign = -1. ;
				dgam = 1./( xl*xl ) ;
				dgam = sign*( ( ct3*dgam+ct2 )*dgam+ct1 )/xl ;
			} /* if ( xlr >= ck2 ) */

		} /* if ( cimag( xl ) >= 0.0 ) */
		else {
			sign = 1. ;
			dgam = 1./( xl*xl ) ;
			dgam = sign*( ( ct3*dgam+ct2 )*dgam+ct1 )/xl ;
		}
	} /* if ( xlr < tsmag ) */
	else dgam = cgam2-cgam1 ;

	den2 = cksm*dgam/( cgam2*( ck1sq*cgam2+ck2sq*cgam1 ) ) ;
	den1 = 1./( cgam1+cgam2 )-cksm/cgam2 ;
	com = dxl*xl*cexp( -cgam2*zph ) ;
	ans[5] = com*b0*den1/ck1 ;
	com *= den2 ;

	if ( rho != 0.0 ) {
		b0p = b0p/rho ;
		ans[0] = -com*xl*( b0p+b0*xl ) ;
		ans[3] = com*xl*b0p ;
	}
	else {
		ans[0] = -com*xl*xl*.5 ;
		ans[3] = ans[0] ;
	}

	ans[1] = com*cgam2*cgam2*b0 ;
	ans[2] = -ans[3]*cgam2*rho ;
	ans[4] = com*b0 ;
}

/* test for convergence in numerical integration */
static void test( double f1r, double f2r, double *tr, double f1i, double f2i, double *ti, double dmin )
{
	double den ;
	
	den = fabs( f2r ) ;
	*tr = fabs( f2i ) ;

	if ( den < *tr ) den = *tr ;
	if ( den < dmin ) den = dmin ;

	if ( den < 1.0e-37 ) {
		*tr=0.0 ;
		*ti=0.0 ;
		return ;
	}
	*tr= fabs( ( f1r- f2r )/ den ) ;
	*ti= fabs( ( f1i- f2i )/ den ) ;
}
