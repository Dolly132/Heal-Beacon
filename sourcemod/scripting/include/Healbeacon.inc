/**
 * This is the include file for HealBeacon
 * To check that HealBeacon is installed and running, verify that the "HealBeacon" library exists
 */

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

public SharedPlugin __pl_HealBeacon = 
{
	name = "HealBeacon",
	file = "HealBeacon.smx",
#if defined REQUIRE_PLUGIN
	required = 1
#else
	required = 0
#endif
};
