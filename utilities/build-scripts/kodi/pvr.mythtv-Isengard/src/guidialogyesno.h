#pragma once
/*
 *      Copyright (C) 2005-2014 Team XBMC
 *      http://www.xbmc.org
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
 *  along with XBMC; see the file COPYING.  If not, write to
 *  the Free Software Foundation, 51 Franklin Street, Fifth Floor, Boston,
 *  MA 02110-1301 USA
 *  http://www.gnu.org/copyleft/gpl.html
 *
 */

#include "client.h"
#include "guidialogbase.h"

class GUIDialogYesNo : public GUIDialogBase
{
public:

  GUIDialogYesNo();
  GUIDialogYesNo(const char *heading, const char *text, int focus);
  ~GUIDialogYesNo();

  bool OnInit();
  bool OnClick(int controlId);
  bool OnAction(int actionId);

  void SetHeading(const char *heading)
  {
    m_heading.assign(heading);
  }
  void SetText(const char *text)
  {
    m_text.assign(text);
  }
  void SetFocus(int focus)
  {
    m_focus = focus;
  }
  bool IsNull()
  {
    return m_response == 0;
  }
  bool IsYes()
  {
    return m_response == 1;
  }
  bool IsNo()
  {
    return m_response == 2;
  }

private:
  std::string m_heading;
  std::string m_text;
  int m_focus;
  int m_response;
};
