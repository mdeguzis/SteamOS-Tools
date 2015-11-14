/*
 *      Copyright (C) 2005-2012 Team XBMC
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

#include "categories.h"
#include "client.h"
#include <platform/os.h>

#define CATEGORIES_FILENAME       "eit_categories.txt"
#define CATEGORIES_MAXLINESIZE    255

using namespace ADDON;

Categories::Categories()
: m_categoriesById()
{
  std::string filePath;
  filePath = g_szClientPath + PATH_SEPARATOR_STRING + "resources" + PATH_SEPARATOR_STRING + CATEGORIES_FILENAME;
  LoadEITCategories(filePath.c_str());
  filePath = g_szUserPath + CATEGORIES_FILENAME;
  LoadEITCategories(filePath.c_str());
  // Copy over
  CategoryByIdMap::const_iterator it;
  for (it = m_categoriesById.begin(); it != m_categoriesById.end(); ++it)
  {
    m_categoriesByName[it->second] = it->first;
  }
}

std::string Categories::Category(int category) const
{
  CategoryByIdMap::const_iterator it = m_categoriesById.find(category);
  if (it != m_categoriesById.end())
    return it->second;
  return "";
}

int Categories::Category(const std::string& category) const
{
  CategoryByNameMap::const_iterator it = m_categoriesByName.find(category);
  if (it != m_categoriesByName.end())
    return it->second;
  return 0;
}

void Categories::LoadEITCategories(const char *filePath)
{
  if (XBMC->FileExists(filePath, false))
  {
    XBMC->Log(LOG_DEBUG, "%s: Loading EIT categories from file '%s'", __FUNCTION__, filePath);
    void *file = XBMC->OpenFile(filePath, 0);
    char *line = new char[CATEGORIES_MAXLINESIZE + 1];
    char *name = new char[CATEGORIES_MAXLINESIZE + 1];
    while (XBMC->ReadFileString(file, line, CATEGORIES_MAXLINESIZE))
    {
      char* end = line + strlen(line);
      char* pos = strchr(line, ';');
      if (pos != NULL)
      {
        bool encaps = false;
        int catId;
        *pos = '\0';
        if (sscanf(line, "%x", &catId) == 1)
        {
          unsigned p = 0;
          memset(name, 0, CATEGORIES_MAXLINESIZE + 1);
          do
          {
            ++pos;
          }
          while (isspace(*pos));
          if (*pos == '"')
            encaps = true;
          while (++pos < end)
          {
            if (encaps && *pos == '"' && *(++pos) != '"')
              break;
            if (!iscntrl(*pos))
              name[p++] = *pos;
          }
          m_categoriesById.insert(std::pair<int, std::string>(catId, name));
          XBMC->Log(LOG_DEBUG, "%s: Add name [%s] for category %.2X", __FUNCTION__, name, catId);
        }
      }
    }
    delete[] name;
    delete[] line;
    XBMC->CloseFile(file);
  }
  else
  {
    XBMC->Log(LOG_INFO, "%s: File '%s' not found", __FUNCTION__, filePath);
  }
}
