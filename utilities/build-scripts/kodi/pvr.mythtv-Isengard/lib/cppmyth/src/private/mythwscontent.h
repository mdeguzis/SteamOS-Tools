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

#ifndef MYTHWSCONTENT_H
#define	MYTHWSCONTENT_H

namespace Myth
{

  typedef enum
  {
    CT_NONE = 0,
    CT_FORM = 1,
    CT_SOAP,
    CT_JSON,
    CT_XML,
    CT_TXT,
    CT_GIF,
    CT_PNG,
    CT_JPG,
    CT_UNKNOWN  // Keep at last
  } CT_t;

  CT_t ContentTypeFromMime(const char *mime);
  const char *MimeFromContentType(CT_t ct);
  const char *ExtnFromContentType(CT_t ct);

}

#endif	/* MYTHWSCONTENT_H */
