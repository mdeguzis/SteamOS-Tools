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

#ifndef MYTHDTO82_H
#define	MYTHDTO82_H

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

namespace MythDTO82
{
  attr_bind_t recording[] =
  {
    { "RecordId",       IS_UINT32,  (setter_t)MythDTO::SetRecording_RecordId },
    { "Priority",       IS_INT32,   (setter_t)MythDTO::SetRecording_Priority },
    { "Status",         IS_INT8,    (setter_t)MythDTO::SetRecording_Status },
    { "EncoderId",      IS_UINT32,  (setter_t)MythDTO::SetRecording_EncoderId },
    { "RecType",        IS_UINT8,   (setter_t)MythDTO::SetRecording_RecType },
    { "DupInType",      IS_UINT8,   (setter_t)MythDTO::SetRecording_DupInType },
    { "DupMethod",      IS_UINT8,   (setter_t)MythDTO::SetRecording_DupMethod },
    { "StartTs",        IS_TIME,    (setter_t)MythDTO::SetRecording_StartTs },
    { "EndTs",          IS_TIME,    (setter_t)MythDTO::SetRecording_EndTs },
    { "Profile",        IS_STRING,  (setter_t)MythDTO::SetRecording_Profile },
    { "RecGroup",       IS_STRING,  (setter_t)MythDTO::SetRecording_RecGroup },
    { "StorageGroup",   IS_STRING,  (setter_t)MythDTO::SetRecording_StorageGroup },
    { "PlayGroup",      IS_STRING,  (setter_t)MythDTO::SetRecording_PlayGroup },
    { "RecordedId",     IS_UINT32,  (setter_t)MythDTO::SetRecording_RecordedId },
  };
  bindings_t RecordingBindArray = { sizeof(recording) / sizeof(attr_bind_t), recording };
}

#endif	/* MYTHDTO82_H */
