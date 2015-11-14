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

#include "mythdto.h"
#include "mythdto75.h"  // Base protocol version 75
#include "mythdto76.h"  // Add protocol version 76
#include "mythdto82.h"  // Add protocol version 82
#include "mythdto85.h"  // Add protocol version 85

#include <cstddef>

const bindings_t *MythDTO::getVersionBindArray(unsigned ranking)
{
  (void)ranking;
  return &MythDTO75::VersionBindArray2_0;
}

const bindings_t *MythDTO::getListBindArray(unsigned proto)
{
  (void)proto;
  return &MythDTO75::ListBindArray;
}

const bindings_t *MythDTO::getChannelBindArray(unsigned proto)
{
  if (proto >= 75)
    return &MythDTO75::ChannelBindArray;
  return NULL;
}

const bindings_t *MythDTO::getRecordingBindArray(unsigned proto)
{
  if (proto >= 82)
    return &MythDTO82::RecordingBindArray;
  if (proto >= 75)
    return &MythDTO75::RecordingBindArray;
  return NULL;
}

const bindings_t *MythDTO::getArtworkBindArray(unsigned proto)
{
  if (proto >= 75)
    return &MythDTO75::ArtworkBindArray;
  return NULL;
}

const bindings_t *MythDTO::getProgramBindArray(unsigned proto)
{
  if (proto >= 75)
    return &MythDTO75::ProgramBindArray;
  return NULL;
}

const bindings_t *MythDTO::getCaptureCardBindArray(unsigned proto)
{
  if (proto >= 75)
    return &MythDTO75::CaptureCardBindArray;
  return NULL;
}

const bindings_t *MythDTO::getVideoSourceBindArray(unsigned proto)
{
  if (proto >= 75)
    return &MythDTO75::VideoSourceBindArray;
  return NULL;
}

const bindings_t *MythDTO::getRecordScheduleBindArray(unsigned proto)
{
  if (proto >= 76)
    return &MythDTO76::RecordScheduleBindArray;
  if (proto >= 75)
    return &MythDTO75::RecordScheduleBindArray;
  return NULL;
}

const bindings_t *MythDTO::getCuttingBindArray(unsigned proto)
{
  if (proto >= 85)
    return &MythDTO85::CuttingBindArray;
  return NULL;
}
