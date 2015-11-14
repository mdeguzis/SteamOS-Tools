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

#ifndef MYTHDTO76_H
#define	MYTHDTO76_H

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

namespace MythDTO76
{
  attr_bind_t recordschedule[] =
  {
    { "Id",               IS_UINT32,  (setter_t)MythDTO::SetSchedule_Id },
    { "ParentId",         IS_UINT32,  (setter_t)MythDTO::SetSchedule_ParentId },
    { "Inactive",         IS_BOOLEAN, (setter_t)MythDTO::SetSchedule_Inactive },
    { "Title",            IS_STRING,  (setter_t)MythDTO::SetSchedule_Title },
    { "SubTitle",         IS_STRING,  (setter_t)MythDTO::SetSchedule_Subtitle },
    { "Description",      IS_STRING,  (setter_t)MythDTO::SetSchedule_Description },
    { "Season",           IS_UINT16,  (setter_t)MythDTO::SetSchedule_Season },
    { "Episode",          IS_UINT16,  (setter_t)MythDTO::SetSchedule_Episode },
    { "Category",         IS_STRING,  (setter_t)MythDTO::SetSchedule_Category },
    { "StartTime",        IS_TIME,    (setter_t)MythDTO::SetSchedule_StartTime },
    { "EndTime",          IS_TIME,    (setter_t)MythDTO::SetSchedule_EndTime },
    { "SeriesId",         IS_STRING,  (setter_t)MythDTO::SetSchedule_SeriesId },
    { "ProgramId",        IS_STRING,  (setter_t)MythDTO::SetSchedule_ProgramId },
    { "Inetref",          IS_STRING,  (setter_t)MythDTO::SetSchedule_Inetref },
    { "ChanId",           IS_UINT32,  (setter_t)MythDTO::SetSchedule_ChanId },
    { "CallSign",         IS_STRING,  (setter_t)MythDTO::SetSchedule_CallSign },
    { "FindDay",          IS_INT8,    (setter_t)MythDTO::SetSchedule_FindDay },
    { "FindTime",         IS_STRING,  (setter_t)MythDTO::SetSchedule_FindTime },
    { "Type",             IS_STRING,  (setter_t)MythDTO::SetSchedule_Type },
    { "SearchType",       IS_STRING,  (setter_t)MythDTO::SetSchedule_SearchType },
    { "RecPriority",      IS_INT8,    (setter_t)MythDTO::SetSchedule_RecPriority },
    { "PreferredInput",   IS_UINT32,  (setter_t)MythDTO::SetSchedule_PreferredInput },
    { "StartOffset",      IS_UINT8,   (setter_t)MythDTO::SetSchedule_StartOffset },
    { "EndOffset",        IS_UINT8,   (setter_t)MythDTO::SetSchedule_EndOffset },
    { "DupMethod",        IS_STRING,  (setter_t)MythDTO::SetSchedule_DupMethod },
    { "DupIn",            IS_STRING,  (setter_t)MythDTO::SetSchedule_DupIn },
    { "Filter",           IS_UINT32,  (setter_t)MythDTO::SetSchedule_Filter },
    { "RecProfile",       IS_STRING,  (setter_t)MythDTO::SetSchedule_RecProfile },
    { "RecGroup",         IS_STRING,  (setter_t)MythDTO::SetSchedule_RecGroup },
    { "StorageGroup",     IS_STRING,  (setter_t)MythDTO::SetSchedule_StorageGroup },
    { "PlayGroup",        IS_STRING,  (setter_t)MythDTO::SetSchedule_PlayGroup },
    { "AutoExpire",       IS_BOOLEAN, (setter_t)MythDTO::SetSchedule_AutoExpire },
    { "MaxEpisodes",      IS_UINT32,  (setter_t)MythDTO::SetSchedule_MaxEpisodes },
    { "MaxNewest",        IS_BOOLEAN, (setter_t)MythDTO::SetSchedule_MaxNewest },
    { "AutoCommflag",     IS_BOOLEAN, (setter_t)MythDTO::SetSchedule_AutoCommflag },
    { "AutoTranscode",    IS_BOOLEAN, (setter_t)MythDTO::SetSchedule_AutoTranscode },
    { "AutoMetaLookup",   IS_BOOLEAN, (setter_t)MythDTO::SetSchedule_AutoMetaLookup },
    { "AutoUserJob1",     IS_BOOLEAN, (setter_t)MythDTO::SetSchedule_AutoUserJob1 },
    { "AutoUserJob2",     IS_BOOLEAN, (setter_t)MythDTO::SetSchedule_AutoUserJob2 },
    { "AutoUserJob3",     IS_BOOLEAN, (setter_t)MythDTO::SetSchedule_AutoUserJob3 },
    { "AutoUserJob4",     IS_BOOLEAN, (setter_t)MythDTO::SetSchedule_AutoUserJob4 },
    { "Transcoder",       IS_UINT32,  (setter_t)MythDTO::SetSchedule_Transcoder },
    { "NextRecording",    IS_TIME,    (setter_t)MythDTO::SetSchedule_NextRecording },
    { "LastRecorded",     IS_TIME,    (setter_t)MythDTO::SetSchedule_LastRecorded },
    { "LastDeleted",      IS_TIME,    (setter_t)MythDTO::SetSchedule_LastDeleted },
    { "AverageDelay",     IS_UINT32,  (setter_t)MythDTO::SetSchedule_AverageDelay },
  };
  bindings_t RecordScheduleBindArray = { sizeof(recordschedule) / sizeof(attr_bind_t), recordschedule };
}

#endif	/* MYTHDTO76_H */

