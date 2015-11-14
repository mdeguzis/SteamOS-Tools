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

#ifndef MYTHDTO_RECORDING_H
#define	MYTHDTO_RECORDING_H

#include "../../mythtypes.h"

namespace MythDTO
{
  void SetRecording_RecordId(Myth::Recording *obj, uint32_t *val) { obj->recordId = *val; }
  void SetRecording_Priority(Myth::Recording *obj, int32_t *val) { obj->priority = *val; }
  void SetRecording_Status(Myth::Recording *obj, int8_t *val) { obj->status = *val; }
  void SetRecording_EncoderId(Myth::Recording *obj, uint32_t *val) { obj->encoderId = *val; }
  void SetRecording_RecType(Myth::Recording *obj, uint8_t *val) { obj->recType = *val; }
  void SetRecording_DupInType(Myth::Recording *obj, uint8_t *val) { obj->dupInType = *val; }
  void SetRecording_DupMethod(Myth::Recording *obj, uint8_t *val) { obj->dupMethod = *val; }
  void SetRecording_StartTs(Myth::Recording *obj, time_t *val) { obj->startTs = *val; }
  void SetRecording_EndTs(Myth::Recording *obj, time_t *val) { obj->endTs = *val; }
  void SetRecording_Profile(Myth::Recording *obj, const char *val) { obj->profile = val; }
  void SetRecording_RecGroup(Myth::Recording *obj, const char *val) { obj->recGroup = val; }
  void SetRecording_StorageGroup(Myth::Recording *obj, const char *val) { obj->storageGroup = val; }
  void SetRecording_PlayGroup(Myth::Recording *obj, const char *val) { obj->playGroup = val; }
  void SetRecording_RecordedId(Myth::Recording *obj, uint32_t *val) { obj->recordedId = *val; }
}

#endif	/* MYTHDTO_RECORDING_H */
