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

#ifndef MYTHSTREAM_H
#define	MYTHSTREAM_H

#include "mythtypes.h"

namespace Myth
{
  class Stream
  {
  public:
    virtual ~Stream() {};
    virtual int64_t GetSize() const = 0;
    virtual int Read(void *buffer, unsigned n) = 0;
    virtual int64_t Seek(int64_t offset, WHENCE_t whence) = 0;
    virtual int64_t GetPosition() const = 0;
  };
}

#endif	/* MYTHSTREAM_H */
