/*
 *      Copyright (C) 2014-2015 Jean-Luc Barriere
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

#ifndef MYTHDEBUG_H
#define	MYTHDEBUG_H

#define MYTH_DBG_NONE  -1
#define MYTH_DBG_ERROR  0
#define MYTH_DBG_WARN   1
#define MYTH_DBG_INFO   2
#define MYTH_DBG_DEBUG  3
#define MYTH_DBG_PROTO  4
#define MYTH_DBG_ALL    6

namespace Myth
{
  void DBGLevel(int l);
  void DBGAll(void);
  void DBGNone(void);
  void DBG(int level, const char* fmt, ...);
  void SetDBGMsgCallback(void (*msgcb)(int level, char*));
}

#endif	/* MYTHDEBUG_H */

