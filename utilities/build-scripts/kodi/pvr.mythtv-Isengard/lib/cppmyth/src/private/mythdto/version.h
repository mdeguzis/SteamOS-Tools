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

#ifndef MYTHDTO_VERSION_H
#define	MYTHDTO_VERSION_H

#include "../../mythtypes.h"

namespace MythDTO
{
  void SetVersion_Version(Myth::Version *obj, const char *val) { obj->version = val; }
  void SetVersion_Protocol(Myth::Version *obj, uint32_t *val) { obj->protocol = *val; }
  void SetVersion_Schema(Myth::Version *obj, uint32_t *val) { obj->schema = *val; }
}

#endif	/* VERSION_H */
