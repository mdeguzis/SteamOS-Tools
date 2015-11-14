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

#include "mytheventhandler.h"
#include "mythdebug.h"
#include "proto/mythprotoevent.h"
#include "private/os/threads/thread.h"
#include "private/os/threads/event.h"
#include "private/cppdef.h"
#include "private/builtin.h"

#include <vector>
#include <map>
#include <list>

using namespace Myth;

///////////////////////////////////////////////////////////////////////////////
////
//// EventHandlerThread
////

EventHandler::EventHandlerThread::EventHandlerThread(const std::string& server, unsigned port)
: m_server(server)
, m_port(port)
{
}

EventHandler::EventHandlerThread::~EventHandlerThread()
{
}

///////////////////////////////////////////////////////////////////////////////
////
//// SubscriptionHandlerThread
////

namespace Myth
{
  class SubscriptionHandlerThread : private OS::CThread
  {
  public:
    SubscriptionHandlerThread(EventSubscriber *handle, unsigned subid);
    virtual ~SubscriptionHandlerThread();
    EventSubscriber *GetHandle() { return m_handle; }
    bool IsRunning() { return OS::CThread::IsRunning(); }
    void PostMessage(const EventMessage& msg);

  private:
    EventSubscriber *m_handle;
    unsigned m_subId;
    mutable OS::CMutex m_mutex;
    OS::CEvent m_queueContent;
    std::list<EventMessagePtr> m_msgQueue;

    bool Start();
    void Stop();
    void *Process();
  };
}

SubscriptionHandlerThread::SubscriptionHandlerThread(EventSubscriber *handle, unsigned subid)
: OS::CThread()
, m_handle(handle)
, m_subId(subid)
, m_mutex()
, m_queueContent()
, m_msgQueue()
{
  if (m_handle && Start())
    DBG(MYTH_DBG_DEBUG, "%s: subscription is started (%p:%u)\n", __FUNCTION__, m_handle, m_subId);
  else
    DBG(MYTH_DBG_ERROR, "%s: subscription failed (%p:%u)\n", __FUNCTION__, m_handle, m_subId);
}

SubscriptionHandlerThread::~SubscriptionHandlerThread()
{
  Stop();
  m_handle = NULL;
}

bool SubscriptionHandlerThread::Start()
{
  if (OS::CThread::IsRunning())
    return true;
  return OS::CThread::StartThread();
}

void SubscriptionHandlerThread::Stop()
{
  if (OS::CThread::IsRunning())
  {
    DBG(MYTH_DBG_DEBUG, "%s: subscription thread (%p:%u)\n", __FUNCTION__, m_handle, m_subId);
    // Set stopping. don't wait as we need to signal the thread first
    OS::CThread::StopThread(false);
    m_queueContent.Signal();
    // Wait for thread to stop
    OS::CThread::StopThread(true);
    DBG(MYTH_DBG_DEBUG, "%s: subscription thread (%p:%u) stopped\n", __FUNCTION__, m_handle, m_subId);
  }
}

void SubscriptionHandlerThread::PostMessage(const EventMessage& msg)
{
  // Critical section
  OS::CLockGuard lock(m_mutex);
  m_msgQueue.push_back(EventMessagePtr(new EventMessage(msg)));
  m_queueContent.Signal();
}

void *SubscriptionHandlerThread::Process()
{
  while (!IsStopped())
  {
    while (!m_msgQueue.empty() && !IsStopped())
    {
      // Critical section
      OS::CLockGuard lock(m_mutex);
      EventMessagePtr msg = m_msgQueue.front();
      m_msgQueue.pop_front();
      lock.Unlock();
      // Do work
      m_handle->HandleBackendMessage(msg);
    }
    // The tread is woken up by m_queueContent.Signal();
    m_queueContent.Wait();
  }
  return NULL;
}

///////////////////////////////////////////////////////////////////////////////
////
//// BasicEventHandler
////

namespace Myth
{
  class BasicEventHandler : public EventHandler::EventHandlerThread, private OS::CThread
  {
  public:
    BasicEventHandler(const std::string& server, unsigned port);
    virtual ~BasicEventHandler();
    // Implements MythEventHandlerThread
    virtual bool Start();
    virtual void Stop();
    virtual void Reset();
    virtual bool IsRunning();
    virtual bool IsConnected();
    virtual unsigned CreateSubscription(EventSubscriber *sub);
    virtual bool SubscribeForEvent(unsigned subid, EVENT_t event);
    virtual void RevokeSubscription(unsigned subid);
    virtual void RevokeAllSubscriptions(EventSubscriber *sub);

  private:
    OS::CMutex m_mutex;
    ProtoEvent *m_event;
    bool m_reset;
    // About subscriptions
    typedef std::map<EVENT_t, std::list<unsigned> > subscriptionsByEvent_t;
    subscriptionsByEvent_t m_subscriptionsByEvent;
    typedef std::map<unsigned, SubscriptionHandlerThread*> subscriptions_t;
    subscriptions_t m_subscriptions;

    void DispatchEvent(const EventMessage& msg);
    virtual void* Process(void);
    void AnnounceStatus(const char *status);
    void AnnounceTimer();
    void RetryConnect();
  };
}

BasicEventHandler::BasicEventHandler(const std::string& server, unsigned port)
: EventHandlerThread(server, port), OS::CThread()
, m_event(new ProtoEvent(server,port))
, m_reset(false)
{
}

BasicEventHandler::~BasicEventHandler()
{
  Stop();
  {
    OS::CLockGuard lock(m_mutex);
    for (subscriptions_t::iterator it = m_subscriptions.begin(); it != m_subscriptions.end(); ++it)
      delete it->second;
    m_subscriptions.clear();
    m_subscriptionsByEvent.clear();
  }
  SAFE_DELETE(m_event);
}

bool BasicEventHandler::Start()
{
  if (OS::CThread::IsRunning())
    return true;
  return OS::CThread::StartThread();
}

void BasicEventHandler::Stop()
{
  if (OS::CThread::IsRunning())
  {
    DBG(MYTH_DBG_DEBUG, "%s: event handler thread (%p)\n", __FUNCTION__, this);
    OS::CThread::StopThread(true);
    DBG(MYTH_DBG_DEBUG, "%s: event handler thread (%p) stopped\n", __FUNCTION__, this);
  }
  if (m_event->IsOpen())
    m_event->Close();
}

void BasicEventHandler::Reset()
{
  // Hold reset
  m_reset = true;
}

bool BasicEventHandler::IsRunning()
{
  return OS::CThread::IsRunning();
}

bool BasicEventHandler::IsConnected()
{
  return m_event->IsOpen();
}

unsigned BasicEventHandler::CreateSubscription(EventSubscriber* sub)
{
  unsigned id = 0;
  OS::CLockGuard lock(m_mutex);
  subscriptions_t::const_reverse_iterator it = m_subscriptions.rbegin();
  if (it != m_subscriptions.rend())
    id = it->first;
  SubscriptionHandlerThread *handler = new SubscriptionHandlerThread(sub, ++id);
  if (handler->IsRunning())
  {
    m_subscriptions.insert(std::make_pair(id, handler));
    return id;
  }
  // Handler didn't start
  delete handler;
  return 0;
}

bool BasicEventHandler::SubscribeForEvent(unsigned subid, EVENT_t event)
{
  OS::CLockGuard lock(m_mutex);
  // Only for registered subscriber
  subscriptions_t::const_iterator it1 = m_subscriptions.find(subid);
  if (it1 == m_subscriptions.end())
    return false;
  std::list<unsigned>::const_iterator it2 = m_subscriptionsByEvent[event].begin();
  while (it2 != m_subscriptionsByEvent[event].end())
  {
    if (*it2 == subid)
      return true;
    ++it2;
  }
  m_subscriptionsByEvent[event].push_back(subid);
  return true;
}

void BasicEventHandler::RevokeSubscription(unsigned subid)
{
  OS::CLockGuard lock(m_mutex);
  subscriptions_t::iterator it;
  it = m_subscriptions.find(subid);
  if (it != m_subscriptions.end())
  {
    delete it->second;
    m_subscriptions.erase(it);
  }
}

void BasicEventHandler::RevokeAllSubscriptions(EventSubscriber *sub)
{
  OS::CLockGuard lock(m_mutex);
  std::vector<subscriptions_t::iterator> its;
  for (subscriptions_t::iterator it = m_subscriptions.begin(); it != m_subscriptions.end(); ++it)
  {
    if (sub == it->second->GetHandle())
      its.push_back(it);
  }
  for (std::vector<subscriptions_t::iterator>::const_iterator it = its.begin(); it != its.end(); ++it)
  {
    delete (*it)->second;
    m_subscriptions.erase(*it);
  }
}

void BasicEventHandler::DispatchEvent(const EventMessage& msg)
{
  OS::CLockGuard lock(m_mutex);
  std::vector<std::list<unsigned>::iterator> revoked;
  std::list<unsigned>::iterator it1 = m_subscriptionsByEvent[msg.event].begin();
  while (it1 != m_subscriptionsByEvent[msg.event].end())
  {
    subscriptions_t::const_iterator it2 = m_subscriptions.find(*it1);
    if (it2 != m_subscriptions.end())
      it2->second->PostMessage(msg);
    else
      revoked.push_back(it1);
    ++it1;
  }
  std::vector<std::list<unsigned>::iterator>::const_iterator itr;
  for (itr = revoked.begin(); itr != revoked.end(); ++itr)
    m_subscriptionsByEvent[msg.event].erase(*itr);
}

void *BasicEventHandler::Process()
{
  // Try to connect
  if (m_event->Open())
    AnnounceStatus(EVENTHANDLER_CONNECTED);
  while (!OS::CThread::IsStopped())
  {
    int r;
    EventMessage msg;
    r = m_event->RcvBackendMessage(EVENTHANDLER_TIMEOUT, msg);
    if (r > 0)
      DispatchEvent(msg);
    else if (r < 0)
    {
      AnnounceStatus(EVENTHANDLER_DISCONNECTED);
      RetryConnect();
    }
    else
    {
      AnnounceTimer();
      // Reconnect if any held reset
      if (m_reset)
      {
        m_reset = false;
        m_event->Close();
        RetryConnect();
      }
    }
  }
  AnnounceStatus(EVENTHANDLER_STOPPED);
  // Close connection
  m_event->Close();
  return NULL;
}

void BasicEventHandler::AnnounceStatus(const char *status)
{
  DBG(MYTH_DBG_DEBUG, "%s: (%p) %s\n", __FUNCTION__, this, status);
  EventMessage msg;
  msg.event = EVENT_HANDLER_STATUS;
  msg.subject.push_back(status);
  msg.subject.push_back(m_server);
  DispatchEvent(msg);
}

void BasicEventHandler::AnnounceTimer()
{
  EventMessage msg;
  msg.event = EVENT_HANDLER_TIMER;
  msg.subject.push_back("");
  DispatchEvent(msg);
}

void BasicEventHandler::RetryConnect()
{
  int c = 0;
  while (!OS::CThread::IsStopped())
  {
    if (--c < 0)
    {
      if (m_event->Open())
      {
        AnnounceStatus(EVENTHANDLER_CONNECTED);
        m_reset = false; // Release to break any loop
        break;
      }
      c = 10; // Retry after 5 seconds
      DBG(MYTH_DBG_INFO, "%s: could not open event socket (%d)\n", __FUNCTION__, m_event->GetSocketErrNo());
      AnnounceStatus(EVENTHANDLER_NOTCONNECTED);
    }
    usleep(500000);
  }
}

///////////////////////////////////////////////////////////////////////////////
////
//// EventHandler
////

EventHandler::EventHandler(const std::string& server, unsigned port)
: m_imp()
{
  // Choose implementation
  m_imp = EventHandlerThreadPtr(new BasicEventHandler(server, port));
}
