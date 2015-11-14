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

#ifndef MYTHDTO85_H
#define	MYTHDTO85_H

#include "mythdto.h"
#include "version.h"
#include "list.h"
#include "program.h"
#include "channel.h"
#include "recording.h"
#include "artwork.h"
#include "capturecard.h"
#include "videosource.h"
#include "recordschedule.h"
#include "cutting.h"

namespace MythDTO85
{
  attr_bind_t cutting[] =
  {
    { "Mark",             IS_INT8,    (setter_t)MythDTO::SetCutting_MarkType },
    { "Offset",           IS_INT64,   (setter_t)MythDTO::SetCutting_MarkValue },
  };
  bindings_t CuttingBindArray = { sizeof(cutting) / sizeof(attr_bind_t), cutting };
}

#endif	/* MYTHDTO85_H */
