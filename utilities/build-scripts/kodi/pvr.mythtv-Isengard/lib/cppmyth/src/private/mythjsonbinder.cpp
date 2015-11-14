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

#include "mythjsonbinder.h"
#include "../private/builtin.h"
#include "../mythdebug.h"

#include <cstdlib>  // for atof
#include <cstring>  // for strcmp
#include <cstdio>
#include <errno.h>

using namespace Myth;

void JSON::BindObject(const Node& node, void *obj, const bindings_t *bl)
{
  int i, err;

  if (bl == NULL)
    return;

  for (i = 0; i < bl->attr_count; ++i)
  {
    const Node& field = node.GetObjectValue(bl->attr_bind[i].field);
    if (field.IsNull())
      continue;
    if (field.IsString())
    {
      std::string value(field.GetStringValue());
      err = 0;
      switch (bl->attr_bind[i].type)
      {
        case IS_STRING:
          bl->attr_bind[i].set(obj, value.c_str());
          break;
        case IS_INT8:
        {
          int8_t num = 0;
          err = string_to_int8(value.c_str(), &num);
          bl->attr_bind[i].set(obj, &num);
          break;
        }
        case IS_INT16:
        {
          int16_t num = 0;
          err = string_to_int16(value.c_str(), &num);
          bl->attr_bind[i].set(obj, &num);
          break;
        }
        case IS_INT32:
        {
          int32_t num = 0;
          err = string_to_int32(value.c_str(), &num);
          bl->attr_bind[i].set(obj, &num);
          break;
        }
        case IS_INT64:
        {
          int64_t num = 0;
          err = string_to_int64(value.c_str(), &num);
          bl->attr_bind[i].set(obj, &num);
          break;
        }
        case IS_UINT8:
        {
          uint8_t num = 0;
          err = string_to_uint8(value.c_str(), &num);
          bl->attr_bind[i].set(obj, &num);
          break;
        }
        case IS_UINT16:
        {
          uint16_t num = 0;
          err = string_to_uint16(value.c_str(), &num);
          bl->attr_bind[i].set(obj, &num);
          break;
        }
        case IS_UINT32:
        {
          uint32_t num = 0;
          err = string_to_uint32(value.c_str(), &num);
          bl->attr_bind[i].set(obj, &num);
          break;
        }
        case IS_DOUBLE:
        {
          double num = atof(value.c_str());
          bl->attr_bind[i].set(obj, &num);
          break;
        }
        case IS_BOOLEAN:
        {
          bool b = (strcmp(value.c_str(), "true") == 0 ? true : false);
          bl->attr_bind[i].set(obj, &b);
          break;
        }
        case IS_TIME:
        {
          time_t time = 0;
          err = string_to_time(value.c_str(), &time);
          bl->attr_bind[i].set(obj, &time);
          break;
        }
        default:
          break;
      }
      if (err)
        Myth::DBG(MYTH_DBG_ERROR, "%s: failed (%d) field \"%s\" type %d: %s\n", __FUNCTION__, err, bl->attr_bind[i].field, bl->attr_bind[i].type, value.c_str());
    }
    else
      Myth::DBG(MYTH_DBG_WARN, "%s: invalid value for field \"%s\" type %d\n", __FUNCTION__, bl->attr_bind[i].field, bl->attr_bind[i].type);
  }
}
