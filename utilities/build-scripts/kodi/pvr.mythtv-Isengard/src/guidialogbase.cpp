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

#include "guidialogbase.h"

GUIDialogBase::GUIDialogBase(const char *xmlFileName, const char *defaultSkin)
: m_xmlFileName(xmlFileName)
, m_defaultSkin(defaultSkin)
, m_window(NULL)
{
}

GUIDialogBase::~GUIDialogBase()
{
}

bool GUIDialogBase::Open()
{
  // Load the Window as Dialog
  m_window = GUI->Window_create(m_xmlFileName.c_str(), m_defaultSkin.c_str(), false, true);
  m_window->m_cbhdl   = this;
  m_window->CBOnInit  = OnInitCB;
  m_window->CBOnFocus = OnFocusCB;
  m_window->CBOnClick = OnClickCB;
  m_window->CBOnAction= OnActionCB;

  m_window->DoModal();

  m_window->ClearList();
  m_window->ClearProperties();
  ClearListItems();
  GUI->Window_destroy(m_window);

  return true;
}

bool GUIDialogBase::OnClick(int controlId)
{
  (void)controlId;
  return false;
}

bool GUIDialogBase::OnFocus(int controlId)
{
  (void)controlId;
  return false;
}

bool GUIDialogBase::OnAction(int actionId)
{
  if (actionId == ADDON_ACTION_CLOSE_DIALOG ||
      actionId == ADDON_ACTION_PREVIOUS_MENU ||
      actionId == ACTION_KEY_STOP ||
      actionId == ACTION_KEY_BACK ||
      actionId == ACTION_KEY_EXIT)
  {
    m_window->Close();
    return true;
  }
  return false;
}

bool GUIDialogBase::OnInitCB(GUIHANDLE cbhdl)
{
  GUIDialogBase* dialog = static_cast<GUIDialogBase*>(cbhdl);
  return dialog->OnInit();
}

bool GUIDialogBase::OnClickCB(GUIHANDLE cbhdl, int controlId)
{
  GUIDialogBase* dialog = static_cast<GUIDialogBase*>(cbhdl);
  return dialog->OnClick(controlId);
}

bool GUIDialogBase::OnFocusCB(GUIHANDLE cbhdl, int controlId)
{
  GUIDialogBase* dialog = static_cast<GUIDialogBase*>(cbhdl);
  return dialog->OnFocus(controlId);
}

bool GUIDialogBase::OnActionCB(GUIHANDLE cbhdl, int actionId)
{
  GUIDialogBase* dialog = static_cast<GUIDialogBase*>(cbhdl);
  return dialog->OnAction(actionId);
}

void GUIDialogBase::ClearListItems()
{
  std::vector<CAddonListItem*>::iterator it;
  for(it = m_listItems.begin(); it != m_listItems.end(); ++it)
  {
    GUI->ListItem_destroy(*it);
  }
  m_listItems.clear();
  m_listItemsMap.clear();
}
