// This program is free software: you can redistribute it and/or
// modify it under the terms of the GNU General Public License as
// published by the Free Software Foundation, either version 3 of the
// License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful, but
// WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
// General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see
// <http://www.gnu.org/licenses/>.


// Ratnay fine Engineering Device Interface Protocol
//
// RfE-dip compatible generic tether point device
//
// "Generic" means that all prims of the object (i. e. device) this
// script is in which are named sCHAINPOINT (i. e. "hook", see below)
// will be reported via the Ratany fine Engineering device interface
// protocol when a compatible device queries this device.  In case
// there are no prims with that name and the script is in the root
// prim, the root prim will be reported.


// rfedip documentation:
//
// This device can be queried for the UUIDs of prims to which chains
// can be attached.  The token to query the device is "tether".  The
// device replies with the token "tether point", followed by the UUID
// of a chaining point.  Each chaining point is reported in a seperate
// response message, one chaining point per message.  When all
// chaining points have been reported, this devices sends a
// RFEDIP_protEND control message.
//
// This device can be queried for what type it is of.  The token to
// query the device for its type is "qry-devtype0".  The device
// replies with the token "devtype0-flags".  The parameter to
// "devtype0-flags" is "0", indicating that this device is of no
// particular type.
//

#define DEBUG0 0  // debug rfedip


// some standard definitions
//
#include <lslstddef.h>

// use the getlinknumbersbyname() function from a library that
// provides functions to deal with names and descriptions of prims in
// order to figure out link numbers
//
#define _USE_getlinknumbersbyname
#include <getlinknumbers.lsl>

// some standard definitions for rfedip:
//
#include <rfedip.h>

// some definitions needed by devices that communicate with this
// device
//
#include <rfedip-devices.h>


// the prims of the device that are points to attach chains to are
// named "hook", unless otherwise defined
#ifndef sCHAINPOINT
#define sCHAINPOINT                "hook"
#endif


#define kHookKey(_n)               llGetLinkKey(llList2Integer(HOOKSLIST, _n))

key kThisDevice;                   // the UUID of this device

// Store the uniq identifier of this device in a string rather than
// calling llGetScriptName() many times --- the string will be
// initiated in the state_entry(), on_rez() and changed() events.  If
// your script is subject to frequent renaming, it may be advisable to
// use a local variable in the listen event instead.
//
string sThis_uniq;

// RFEDIP_sTHIS_UNIQ has been defined in rfedip.h, so redefine it.
// When rfedip.h is included after RFEDIP_sTHIS_UNIQ is defined, it
// doesn´t need to be undefined first.
//
#undef RFEDIP_sTHIS_UNIQ
#define RFEDIP_sTHIS_UNIQ          sThis_uniq


list lHooks;
#define HOOKSLIST                  lHooks

#define virtualHooksInit           HOOKSLIST = getlinknumbersbyname(sCHAINPOINT); unless(Len(HOOKSLIST)) { HOOKSLIST = (list)llGetLinkNumber(); }


#define virtualIDinit					       \
	kThisDevice = llGetLinkKey(llGetLinkNumber());	       \
	sThis_uniq = llGetScriptName()


default
{
	event state_entry()
	{
		// Remember the link numbers of the chain targets
		// rather than creating the list every time the device
		// is queried.
		//
		virtualHooksInit;

		// Remember the uuid and the uniq identifier of this
		// device.
		//
		virtualIDinit;

		// permanently listen on the protocol channel
		//
		llListen(RFEDIP_CHANNEL, "", NULL_KEY, "");
	}
	event changed(int w)
	{
		// maybe do something else here if you need to sit on
		// this device
		//
		when(w & CHANGED_LINK)
			{
				virtualHooksInit;
				virtualIDinit;
			}
	}

	event listen(int channel, string name, key other_device, string _MESSAGE)
	{
		DEBUGmsg0("-->", other_device, _MESSAGE);

		when(ProtocolID(RFEDIP_protIDENTIFY_QUERY))
		{
			// The incoming message looks like:
			//
			// "identify|<sender-Uniq>"
			//
			// Default for the uniq identifier is what
			// llGetScriptName() returns.  Please see
			// rfedip.h.
			//
			// Indistinctively answer queries that want to
			// detect this device: The answer goes to the
			// sender (i. e. other_device) and looks like:
			//
			// "<this-device-uuid>|<RFEDIP_sTHIS_UNIQ>|<recipient-uuid>|<recipient-Uniq>|RFEDIP_sVERSION|RFEDIP_protIDENTIFY"
			//
			// For the device that receives the answer to
			// the request to identify, <this-device-uuid>
			// is the UUID of this device.
			//
			// With
			//
			//   RFEDIP_RESPOND(<recipient-uuid>, <recipient-Uniq>, <sender-uuid>, <protocol-payload>);
			//
			// an answer is sent to the device from which
			// this device has received the request to
			// identify itself:
			//

			DEBUGmsg0("--> ID query from", RemoteName(other_device), "(", other_device, ")");

			RFEDIP_RESPOND(other_device, RFEDIP_ToSENDER_UNIQ(ProtocolData(RFEDIP_sSEP)), kThisDevice, RFEDIP_CHANNEL, RFEDIP_protIDENTIFY);

			DEBUGmsg0("<--", other_device, RFEDIP_CHANNEL, RFEDIP_ToRESPONSE(kThisDevice, other_device, RFEDIP_ToSENDER_UNIQ(ProtocolData(RFEDIP_sSEP)), RFEDIP_protIDENTIFY));

			return;
		}

		// From here on, received messages are expected to
		// look like:
		//
		// "<sender-uuid>|<sender-Uniq>|<recipient-uuid>|<recipient-Uniq>|RFEDIP_sVERSION|<token>[|parameter|parameter...]"
		//
		// <sender-uuid> is the UUID of the device sending the
		// message (i. e. other_device); <recipient-uuid> is
		// the UUID of the recipient, i. e. of this device
		//
		// same goes for <sender-Uniq> and <recipient-Uniq>
		//
		// Please do not confuse incoming messages with
		// outgoing messages!
		//
		// Parameters can be tokens.  However, this is not
		// recommended.  Send multiple messages rather than
		// multiple tokens in one message.
		//
		// The received message is put into a list for further
		// processing:
		//
		list payload = ProtocolData(RFEDIP_sSEP);

		// Attempt to verify whether the message looks valid:
		//
		if(Len(payload) < RFEDIP_iMINMSGLEN)
			{
				return;
			}

		// Attempt to make sure that the message is for this
		// device:
		//
		// + ignore messages that appear not to be sent by the
		//   device they claim to be sent from by verifying
		//   the sender given in the message with the actual
		//   sender:
		//
#define InvalidSender (RFEDIP_ToSENDER(payload) != other_device)
		//
		// + ignore messages that appear not be destined for
		//   this device by verifying the recipient given in
		//   the message with what this device actually is:
		//
#define NotDestined   (RFEDIP_ToRCPT(payload) != kThisDevice)
		//
		// + ignore messages that appear not to be destined for
		//   this device by verifying the Uniq identifiers
		//
#define UniqMismatch (RFEDIP_ToRCPT_UNIQ(payload) != RFEDIP_sTHIS_UNIQ)
		DEBUGmsg0("this rcpt-uuid:", RFEDIP_ToRCPT(payload));
		DEBUGmsg0("this rcpt-Uniq:", RFEDIP_ToRCPT_UNIQ(payload));

		DEBUGmsg0("this this-uuid:", kThisDevice);
		DEBUGmsg0("this this-Uniq:", RFEDIP_sTHIS_UNIQ);

		DEBUGmsg0("sndr sndr-uuid:", RFEDIP_ToSENDER(payload));
		DEBUGmsg0("sndr sndr-Uniq:", RFEDIP_ToSENDER_UNIQ(payload));
		DEBUGmsg0("otrh othr-uuid:", other_device);

		DEBUGmsg0("<--- test-resp:", RFEDIP_ToRESPONSE(kThisDevice, other_device, RFEDIP_ToSENDER_UNIQ(payload), "test"));
		DEBUGmsg0("incoming msg  :", _MESSAGE);
		//
		// + ignore messages that request a different version
		//   of the protocol by verifying the protocol version
		//   given in the message --- in this example, a check
		//   for what is considered a "sufficient version" is
		//   applied:
		//
#define BadVersion    !Instr(RFEDIP_ToPROTVERSION(payload), RFEDIP_sSUFFICIENT_VERSION)
		//
		when(InvalidSender || NotDestined || UniqMismatch || BadVersion)
			{
				return;
			}

#undef InvalidSender
#undef NotDestined
#undef UniqMismatch
#undef BadVersion

		// From here on, the capabilities of the device can be
		// implemented.
		//

		// extract the token from the rfedip message ...
		//
		string token = RFEDIP_ToFirstTOKEN(payload);
		//
		// ... and the uniq identifier of the sender
		//
		string uniq = RFEDIP_ToSENDER_UNIQ(payload);

		// Report the device type and send end of
		// communication message.
		//
		when(protDEVTYPE0_QUERY == token)
			{
				// this is some generic device of no particular type
				//
				RFEDIP_RESPOND(other_device, uniq, kThisDevice, RFEDIP_CHANNEL, protDEVTYPE0_FLAGS, RFEDIP_FLAG_DEVTYPE0_UNDETERMINED);
				DEBUGmsg0(other_device, uniq, kThisDevice, RFEDIP_CHANNEL, protDEVTYPE0_FLAGS, RFEDIP_FLAG_DEVTYPE0_UNDETERMINED);
				RFEDIP_END(other_device, uniq, kThisDevice, RFEDIP_CHANNEL);
				return;
			}


		// Report the chain target points and send end of
		// communication message.
		//
		when(token == protTETHER)
			{
				int n = Len(HOOKSLIST);
				LoopDown(n, RFEDIP_RESPOND(other_device, uniq, kThisDevice, RFEDIP_CHANNEL, protTETHER_RESPONSE, kHookKey(n)));
				// RFEDIP_END(other_device, kThisDevice, RFEDIP_CHANNEL);
				// return;
			}

		unless(RFEDIP_protEND == token)
			{
				// when receiving messages not handled by this device,
				// indicate end of communication to potentially save
				// other devices unnecessary waiting times
				//
				// do not answer with com/end to com/end messages to avoid message loops!
				//
				RFEDIP_END(other_device, uniq, kThisDevice, RFEDIP_CHANNEL);
			}
	}

	event on_rez(int p)
	{
		// Remember the uuid and the uniq identifier of this
		// device.
		//
		virtualIDinit;
	}
}
