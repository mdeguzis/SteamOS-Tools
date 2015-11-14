/*
 *      Copyright (C) 2014 Jean-Luc Barriere
 *
 *  This Program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2, or (at your option)
 *  any later version.
 *
 *  This Program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; see the file COPYING.  If not, write to
 *  the Free Software Foundation, 51 Franklin Street, Fifth Floor, Boston,
 *  MA 02110-1301 USA
 *  http://www.gnu.org/copyleft/gpl.html
 *
 */

#ifndef MYTHPROTOEVENT_H
#define	MYTHPROTOEVENT_H

#include "mythprotobase.h"

#define PROTO_EVENT_RCVBUF        64000

namespace Myth
{

  class ProtoEvent : public ProtoBase
  {
  public:
    ProtoEvent(const std::string& server, unsigned port);

    virtual bool Open();
    virtual void Close();

    /**
     * @brief Wait for new backend message from event connection
     * @param timeout Number of seconds
     * @param msg Handle MythEventMessage
     * @return success: 0 = No message, 1 = New message received
     * @return failure: -(errno)
     */
    int RcvBackendMessage(unsigned timeout, EventMessage& msg);

  private:
    bool Announce75();
    SignalStatusPtr RcvSignalStatus();
  };

}

#endif	/* MYTHPROTOEVENT_H */
