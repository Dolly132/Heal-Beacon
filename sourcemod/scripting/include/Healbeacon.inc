#if defined _Healbeacon_included_
  #endinput
#endif
#define _Healbeacon_included_

/**
 * Returns The first random beacon heal player
 *
 * @return int    Client index of the Random1 (-1 = null)
 */
native int IsBeaconPlayer1();
/**
 * Returns The second random beacon heal player
 *
 * @return int    Client index of the Random2 (-1 = null)
 */
native int IsBeaconPlayer2();
