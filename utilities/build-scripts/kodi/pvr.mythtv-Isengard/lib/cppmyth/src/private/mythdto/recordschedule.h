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

#ifndef MYTHDTO_RECORDSCHEDULE_H
#define	MYTHDTO_RECORDSCHEDULE_H

#include "../../mythtypes.h"

namespace MythDTO
{
  void SetSchedule_Id(Myth::RecordSchedule *obj, uint32_t *val) { obj->recordId = *val; }
  void SetSchedule_Title(Myth::RecordSchedule *obj, const char *val) { obj->title = val; }
  void SetSchedule_Subtitle(Myth::RecordSchedule *obj, const char *val) { obj->subtitle = val; }
  void SetSchedule_Description(Myth::RecordSchedule *obj, const char *val) { obj->description = val; }
  void SetSchedule_Category(Myth::RecordSchedule *obj, const char *val) { obj->category = val; }
  void SetSchedule_StartTime(Myth::RecordSchedule *obj, time_t *val) { obj->startTime = *val; }
  void SetSchedule_EndTime(Myth::RecordSchedule *obj, time_t *val) { obj->endTime = *val; }
  void SetSchedule_SeriesId(Myth::RecordSchedule *obj, const char *val) { obj->seriesId = val; }
  void SetSchedule_ProgramId(Myth::RecordSchedule *obj, const char *val) { obj->programId = val; }
  void SetSchedule_ChanId(Myth::RecordSchedule *obj, uint32_t *val) { obj->chanId = *val; }
  void SetSchedule_CallSign(Myth::RecordSchedule *obj, const char *val) { obj->callSign = val; }
  void SetSchedule_FindDay(Myth::RecordSchedule *obj, int8_t *val) { obj->findDay = *val; }
  void SetSchedule_FindTime(Myth::RecordSchedule *obj, const char *val) { obj->findTime = val; }
  void SetSchedule_ParentId(Myth::RecordSchedule *obj, uint32_t *val) { obj->parentId = *val; }
  void SetSchedule_Inactive(Myth::RecordSchedule *obj, bool *val) { obj->inactive = *val; }
  void SetSchedule_Season(Myth::RecordSchedule *obj, uint16_t *val) { obj->season = *val; }
  void SetSchedule_Episode(Myth::RecordSchedule *obj, uint16_t *val) { obj->episode = *val; }
  void SetSchedule_Inetref(Myth::RecordSchedule *obj, const char *val) { obj->inetref = val; }
  void SetSchedule_Type(Myth::RecordSchedule *obj, const char *val) { obj->type = val; }
  void SetSchedule_SearchType(Myth::RecordSchedule *obj, const char *val) { obj->searchType = val; }
  void SetSchedule_RecPriority(Myth::RecordSchedule *obj, int8_t *val) { obj->recPriority = *val; }
  void SetSchedule_PreferredInput(Myth::RecordSchedule *obj, uint32_t *val) { obj->preferredInput = *val; }
  void SetSchedule_StartOffset(Myth::RecordSchedule *obj, uint8_t *val) { obj->startOffset = *val; }
  void SetSchedule_EndOffset(Myth::RecordSchedule *obj, uint8_t *val) { obj->endOffset = *val; }
  void SetSchedule_DupMethod(Myth::RecordSchedule *obj, const char *val) { obj->dupMethod = val; }
  void SetSchedule_DupIn(Myth::RecordSchedule *obj, const char *val) { obj->dupIn = *val; }
  void SetSchedule_Filter(Myth::RecordSchedule *obj, uint32_t *val) { obj->filter = *val; }
  void SetSchedule_RecProfile(Myth::RecordSchedule *obj, const char *val) { obj->recProfile = val; }
  void SetSchedule_RecGroup(Myth::RecordSchedule *obj, const char *val) { obj->recGroup = val; }
  void SetSchedule_StorageGroup(Myth::RecordSchedule *obj, const char *val) { obj->storageGroup = val; }
  void SetSchedule_PlayGroup(Myth::RecordSchedule *obj, const char *val) { obj->playGroup = val; }
  void SetSchedule_AutoExpire(Myth::RecordSchedule *obj, bool *val) { obj->autoExpire = *val; }
  void SetSchedule_MaxEpisodes(Myth::RecordSchedule *obj, uint32_t *val) { obj->maxEpisodes = *val; }
  void SetSchedule_MaxNewest(Myth::RecordSchedule *obj, bool *val) { obj->maxNewest = *val; }
  void SetSchedule_AutoCommflag(Myth::RecordSchedule *obj, bool *val) { obj->autoCommflag = *val; }
  void SetSchedule_AutoTranscode(Myth::RecordSchedule *obj, bool *val) { obj->autoTranscode = *val; }
  void SetSchedule_AutoMetaLookup(Myth::RecordSchedule *obj, bool *val) { obj->autoMetaLookup = *val; }
  void SetSchedule_AutoUserJob1(Myth::RecordSchedule *obj, bool *val) { obj->autoUserJob1 = *val; }
  void SetSchedule_AutoUserJob2(Myth::RecordSchedule *obj, bool *val) { obj->autoUserJob2 = *val; }
  void SetSchedule_AutoUserJob3(Myth::RecordSchedule *obj, bool *val) { obj->autoUserJob3 = *val; }
  void SetSchedule_AutoUserJob4(Myth::RecordSchedule *obj, bool *val) { obj->autoUserJob4 = *val; }
  void SetSchedule_Transcoder(Myth::RecordSchedule *obj, uint32_t *val) { obj->transcoder = *val; }
  void SetSchedule_NextRecording(Myth::RecordSchedule *obj, time_t *val) { obj->nextRecording = *val; }
  void SetSchedule_LastRecorded(Myth::RecordSchedule *obj, time_t *val) { obj->lastRecorded = *val; }
  void SetSchedule_LastDeleted(Myth::RecordSchedule *obj, time_t *val) { obj->lastDeleted = *val; }
  void SetSchedule_AverageDelay(Myth::RecordSchedule *obj, uint32_t *val) { obj->averageDelay = *val; }
}

#endif	/* MYTHDTO_RECORDSCHEDULE_H */

