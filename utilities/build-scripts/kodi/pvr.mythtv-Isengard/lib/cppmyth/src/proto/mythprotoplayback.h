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

#ifndef MYTHPROTOPLAYBACK_H
#define	MYTHPROTOPLAYBACK_H

#include "mythprotobase.h"
#include "mythprototransfer.h"

#define PROTO_PLAYBACK_RCVBUF      64000

namespace Myth
{

  class ProtoPlayback : public ProtoBase
  {
  public:
    ProtoPlayback(const std::string& server, unsigned port);

    virtual bool Open();
    virtual void Close();
    virtual bool IsOpen();

    void TransferDone(ProtoTransfer& transfer)
    {
      TransferDone75(transfer);
    }
    bool TransferIsOpen(ProtoTransfer& transfer)
    {
      return TransferIsOpen75(transfer);
    }
    int TransferRequestBlock(ProtoTransfer& transfer, void *buffer, unsigned n);
    int64_t TransferSeek(ProtoTransfer& transfer, int64_t offset, WHENCE_t whence)
    {
      return TransferSeek75(transfer, offset, whence);
    }

  private:
    bool Announce75();
    void TransferDone75(ProtoTransfer& transfer);
    bool TransferIsOpen75(ProtoTransfer& transfer);
    bool TransferRequestBlock75(ProtoTransfer& transfer, unsigned n);
    int32_t TransferRequestBlockFeedback75();
    int64_t TransferSeek75(ProtoTransfer& transfer, int64_t offset, WHENCE_t whence);
  };

}

#endif	/* MYTHPROTOPLAYBACK_H */
