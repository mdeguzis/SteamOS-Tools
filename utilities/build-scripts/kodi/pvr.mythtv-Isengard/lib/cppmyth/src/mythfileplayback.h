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

#ifndef MYTHFILEPLAYBACK_H
#define	MYTHFILEPLAYBACK_H

#include "proto/mythprotoplayback.h"
#include "proto/mythprototransfer.h"
#include "mythstream.h"

namespace Myth
{

  class FilePlayback : private ProtoPlayback, public Stream
  {
  public:
    FilePlayback(const std::string& server, unsigned port);
    ~FilePlayback();

    bool Open();
    void Close();
    bool IsOpen() { return ProtoPlayback::IsOpen(); }
    bool OpenTransfer(const std::string& pathname, const std::string& sgname);
    void CloseTransfer();
    bool TransferIsOpen();

    // Implement Stream
    int64_t GetSize() const;
    int Read(void *buffer, unsigned n);
    int64_t Seek(int64_t offset, WHENCE_t whence);
    int64_t GetPosition() const;

  private:
    ProtoTransferPtr m_transfer;
  };

}

#endif	/* MYTHFILEPLAYBACK_H */
