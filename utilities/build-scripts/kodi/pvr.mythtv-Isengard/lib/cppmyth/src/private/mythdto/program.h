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

#ifndef MYTHDTO_PROGRAM_H
#define	MYTHDTO_PROGRAM_H

#include "../../mythtypes.h"

namespace MythDTO
{
  void SetProgram_StartTime(Myth::Program *obj, time_t *val) { obj->startTime = *val; }
  void SetProgram_EndTime(Myth::Program *obj, time_t *val) { obj->endTime = *val; }
  void SetProgram_Title(Myth::Program *obj, const char *val) { obj->title = val; }
  void SetProgram_SubTitle(Myth::Program *obj, const char *val) { obj->subTitle = val; }
  void SetProgram_Description(Myth::Program *obj, const char *val) { obj->description = val; }
  void SetProgram_Season(Myth::Program *obj, uint16_t *val) { obj->season = *val; }
  void SetProgram_Episode(Myth::Program *obj, uint16_t *val) { obj->episode = *val; }
  void SetProgram_Category(Myth::Program *obj, const char *val) { obj->category = val; }
  void SetProgram_CatType(Myth::Program *obj, const char *val) { obj->catType = val; }
  void SetProgram_HostName(Myth::Program *obj, const char *val) { obj->hostName = val; }
  void SetProgram_FileName(Myth::Program *obj, const char *val) { obj->fileName = val; }
  void SetProgram_FileSize(Myth::Program *obj, int64_t *val) { obj->fileSize = *val; }
  void SetProgram_Repeat(Myth::Program *obj, bool *val) { obj->repeat = *val; }
  void SetProgram_ProgramFlags(Myth::Program *obj, uint32_t *val) { obj->programFlags = *val; }
  void SetProgram_SeriesId(Myth::Program *obj, const char *val) { obj->seriesId = val; }
  void SetProgram_ProgramId(Myth::Program *obj, const char *val) { obj->programId = val; }
  void SetProgram_Inetref(Myth::Program *obj, const char *val) { obj->inetref = val; }
  void SetProgram_LastModified(Myth::Program *obj, time_t *val) { obj->lastModified = *val; }
  void SetProgram_Stars(Myth::Program *obj, const char *val) { obj->stars = val; }
  void SetProgram_Airdate(Myth::Program *obj, time_t *val) { obj->airdate = *val; }
  void SetProgram_AudioProps(Myth::Program *obj, uint16_t *val) { obj->audioProps = *val; }
  void SetProgram_VideoProps(Myth::Program *obj, uint16_t *val) { obj->videoProps = *val; }
  void SetProgram_SubProps(Myth::Program *obj, uint16_t *val) { obj->subProps = *val; }
}

#endif	/* MYTHDTO_PROGRAM_H */
