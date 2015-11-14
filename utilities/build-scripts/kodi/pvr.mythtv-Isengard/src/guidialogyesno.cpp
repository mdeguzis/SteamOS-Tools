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

#include "guidialogyesno.h"

#define GUI_XMLFILENAME       "DialogYesNo.xml"
#define GUI_DEFAULTSKIN       "skin.confluence"
#define CONTROL_HEADING       1
#define CONTROL_TEXT          9
#define CONTROL_BUTTON_NO     10
#define CONTROL_BUTTON_YES    11

using namespace ADDON;

GUIDialogYesNo::GUIDialogYesNo()
: GUIDialogBase(GUI_XMLFILENAME, GUI_DEFAULTSKIN)
, m_heading()
, m_text()
, m_focus(0)
, m_response(0)
{
}

GUIDialogYesNo::GUIDialogYesNo(const char *heading, const char *text, int focus)
: GUIDialogBase(GUI_XMLFILENAME, GUI_DEFAULTSKIN)
, m_heading(heading)
, m_text(text)
, m_focus(focus)
, m_response(0)
{
}

GUIDialogYesNo::~GUIDialogYesNo()
{
}

bool GUIDialogYesNo::OnInit()
{
  m_window->SetControlLabel(CONTROL_BUTTON_YES, XBMC->GetLocalizedString(107));
  m_window->SetControlLabel(CONTROL_BUTTON_NO, XBMC->GetLocalizedString(106));
  m_window->SetControlLabel(CONTROL_HEADING, m_heading.c_str());
  m_window->SetControlLabel(CONTROL_TEXT, m_text.c_str());
  switch(m_focus)
  {
    case 1:
      m_window->SetFocusId(CONTROL_BUTTON_YES);
      break;
    case 2:
      m_window->SetFocusId(CONTROL_BUTTON_NO);
      break;
    default:
      m_window->SetFocusId(CONTROL_TEXT);
      break;
  }
  return true;
}

bool GUIDialogYesNo::OnClick(int controlId)
{
  if (controlId == CONTROL_BUTTON_YES)
  {
    m_response = 1;
    m_window->Close();
    return true;
  }
  if (controlId == CONTROL_BUTTON_NO)
  {
    m_response = 2;
    m_window->Close();
    return true;
  }
  return false;
}

bool GUIDialogYesNo::OnAction(int actionId)
{
  return GUIDialogBase::OnAction(actionId);
}
