/**
 * This is the include file for HealBeacon
 * To check that HealBeacon is installed and running, verify that the "HealBeacon" library exists
 */

#if defined _HealBeacon_included_
  #endinput
#endif
#define _HealBeacon_included_

/**
 * Returns true/false
 *
 * @return bool    true if the client is a heal beaconed player, false otherwise
 */
native bool IsPlayerRandom(int client);

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
