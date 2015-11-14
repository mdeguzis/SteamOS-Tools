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

#ifndef MYTHDTO_H
#define	MYTHDTO_H

/**
 * @brief Enemerates field types known to be binded
 */
typedef enum
{
  IS_STRING = 0,
  IS_INT8,
  IS_INT16,
  IS_INT32,
  IS_INT64,
  IS_UINT8,
  IS_UINT16,
  IS_UINT32,
  IS_DOUBLE,
  IS_TIME,
  IS_BOOLEAN,
} FT_t;


/**
 * @brief Definition of function setter
 * @param 1 pointer to object handle
 * @param 2 pointer to value
 */
typedef void(*setter_t)(void *, const void *);

/**
 * @struct attr_bind_t
 * @brief Definition of binding from a source field to an object attribute
 */
typedef struct
{
  const char *field;                  /**< name of source field */
  FT_t type;                          /**< type of source field */
  void(*set)(void *, const void *);   /**< function setter */
} attr_bind_t;

/**
 * @struct bindings_t
 * @brief Brings together all attribute bindings of an object
 */
typedef struct
{
  int attr_count;                     /**< count binded attribute */
  attr_bind_t *attr_bind;             /**< pointer to the first element */
} bindings_t;

/**
 * @namespace MythDTO
 * @brief This namespace contains all DTO definitions
 */
namespace MythDTO
{
  /** @brief Returns bindings for Myth::Version */
  const bindings_t *getVersionBindArray(unsigned ranking);
  /** @brief Returns bindings for Myth::List */
  const bindings_t *getListBindArray(unsigned proto);
  /** @brief Returns bindings for Myth::Channel */
  const bindings_t *getChannelBindArray(unsigned proto);
  /** @brief Returns bindings for Myth::Recording */
  const bindings_t *getRecordingBindArray(unsigned proto);
  /** @brief Returns bindings for Myth::Artwork */
  const bindings_t *getArtworkBindArray(unsigned proto);
  /** @brief Returns bindings for Myth::Program */
  const bindings_t *getProgramBindArray(unsigned proto);
  /** @brief Returns bindings for Myth::CaptureCard */
  const bindings_t *getCaptureCardBindArray(unsigned proto);
  /** @brief Returns bindings for Myth::VideoSource */
  const bindings_t *getVideoSourceBindArray(unsigned proto);
  /** @brief Returns bindings for Myth::RecordSchedule */
  const bindings_t *getRecordScheduleBindArray(unsigned proto);
  /** @brief Returns bindings for Myth::Mark */
  const bindings_t *getCuttingBindArray(unsigned proto);
}

#endif	/* MYTHDTO_H */
