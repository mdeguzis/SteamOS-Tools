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

#ifndef MYTHWSSTREAM_H
#define	MYTHWSSTREAM_H

#include "mythtypes.h"
#include "mythstream.h"

namespace Myth
{
  class WSStream;
  class WSResponse;

  typedef MYTH_SHARED_PTR<WSStream> WSStreamPtr;

  class WSStream : public Stream
  {
  public:
    WSStream();
    WSStream(WSResponse *response);
    ~WSStream();

    bool EndOfStream();

    int Read(void* buffer, unsigned n);
    int64_t GetSize() const;
    int64_t GetPosition() const;
    int64_t Seek(int64_t offset, WHENCE_t whence);

  private:
    WSResponse *m_response;
  };
}

#endif	/* MYTHWSSTREAM_H */

