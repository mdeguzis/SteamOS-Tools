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

#ifndef MYTHDTO_CHANNEL_H
#define	MYTHDTO_CHANNEL_H

#include "../../mythtypes.h"

namespace MythDTO
{
  void SetChannel_ChanId(Myth::Channel *obj, uint32_t *val) { obj->chanId = *val; }
  void SetChannel_ChanNum(Myth::Channel *obj, const char *val) { obj->chanNum = val; }
  void SetChannel_CallSign(Myth::Channel *obj, const char *val) { obj->callSign = val; }
  void SetChannel_IconURL(Myth::Channel *obj, const char *val) { obj->iconURL = val; }
  void SetChannel_ChannelName(Myth::Channel *obj, const char *val) { obj->channelName = val; }
  void SetChannel_MplexId(Myth::Channel *obj, uint32_t *val) { obj->mplexId = *val; }
  void SetChannel_CommFree(Myth::Channel *obj, const char *val) { obj->commFree = val; }
  void SetChannel_ChanFilters(Myth::Channel *obj, const char *val) { obj->chanFilters = val; }
  void SetChannel_SourceId(Myth::Channel *obj, uint32_t *val) { obj->sourceId = *val; }
  void SetChannel_InputId(Myth::Channel *obj, uint32_t *val) { obj->inputId = *val; }
  void SetChannel_Visible(Myth::Channel *obj, bool *val) { obj->visible = *val; }
}

#endif	/* MYTHDTO_CHANNEL_H */
