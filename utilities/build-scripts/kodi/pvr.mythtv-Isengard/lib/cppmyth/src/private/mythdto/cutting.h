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

#ifndef MYTHDTO_CUTTING_H
#define	MYTHDTO_CUTTING_H

#include "../../mythtypes.h"

namespace MythDTO
{
  void SetCutting_MarkType(Myth::Mark *obj, int8_t *val) { obj->markType = static_cast<Myth::MARK_t>(*val); }
  void SetCutting_MarkValue(Myth::Mark *obj, int64_t *val) { obj->markValue = *val; }
}

#endif	/* MYTHDTO_CUTTING_H */
