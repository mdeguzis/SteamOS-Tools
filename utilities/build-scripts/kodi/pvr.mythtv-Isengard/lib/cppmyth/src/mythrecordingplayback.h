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

#ifndef MYTHRECORDINGPLAYBACK_H
#define	MYTHRECORDINGPLAYBACK_H

#include "proto/mythprotoplayback.h"
#include "proto/mythprototransfer.h"
#include "mythstream.h"
#include "mytheventhandler.h"

namespace Myth
{

  class RecordingPlayback : private ProtoPlayback, public Stream, private EventSubscriber
  {
  public:
    RecordingPlayback(EventHandler& handler);
    RecordingPlayback(const std::string& server, unsigned port);
    ~RecordingPlayback();

    bool Open();
    void Close();
    bool IsOpen() { return ProtoPlayback::IsOpen(); }
    bool OpenTransfer(ProgramPtr recording);
    void CloseTransfer();
    bool TransferIsOpen();

    // Implement Stream
    int64_t GetSize() const;
    int Read(void *buffer, unsigned n);
    int64_t Seek(int64_t offset, WHENCE_t whence);
    int64_t GetPosition() const;

    // Implement EventSubscriber
    void HandleBackendMessage(EventMessagePtr msg);

  private:
    EventHandler m_eventHandler;
    unsigned m_eventSubscriberId;
    ProtoTransferPtr m_transfer;
    ProgramPtr m_recording;
    volatile bool m_readAhead;
  };

}

#endif	/* MYTHRECORDINGPLAYBACK_H */
