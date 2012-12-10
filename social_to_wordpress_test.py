#!/usr/bin/python
"""Unit tests for social_to_wordpress.py.
"""

__author__ = ['Ryan Barrett <social_to_wordpress@ryanb.org>']

import datetime
# import json
# import re
# import os

from activitystreams.webutil import testutil
import social_to_wordpress


class Test(testutil.HandlerTest):

  xmlrpc = social_to_wordpress.XmlRpc('http://abc/def.php', 123,
                                      'my_user', 'my_passwd')

  def setUp(self):
    super(Test, self).setUp()
    social_to_wordpress.PAUSE_SEC = 0
    self.xmlrpc.proxy.wp = self.mox.CreateMockAnything()

  def test_basic(self):
    self.xmlrpc.proxy.wp.newPost(123, 'my_user', 'my_passwd', {
        'post_type': 'post',
        'post_status': 'publish',
        'post_title': 'Anyone in or near Paris right now',
        'post_content': """\
Anyone in or near Paris right now? Interested in dinner any time Sun-Wed? There are a couple more chefs I'm hoping to check out before I head south, and I also have a seat free for an incredible reservation Tues night.<p class="fb-tags"></p><p class="fb-via">\n<a href="http://facebook.com/permalink.php?id=tag:facebook.com,2012:212038&story_fbid=157673343490">via Facebook</a>\n</p>""",
        'post_date': datetime.datetime(2009, 10, 15, 22, 05, 49),
        'comment_status': 'open',
        'terms_names': {'post_tag': social_to_wordpress.POST_TAGS},
        })

    self.mox.ReplayAll()
    social_to_wordpress.post_to_wordpress(self.xmlrpc, {
        "id": "212038_157673343490",
        "from": {
          "name": "Ryan Barrett",
          "id": "212038"
          },
        "message": "Anyone in or near Paris right now? Interested in dinner any time Sun-Wed? There are a couple more chefs I'm hoping to check out before I head south, and I also have a seat free for an incredible reservation Tues night.",
        "type": "status",
        "status_type": "mobile_status_update",
        "created_time": "2009-10-15T22:05:49+0000",
        "updated_time": "2009-10-16T03:50:08+0000"
        })

  def test_comments(self):
    post_id = 222
    self.xmlrpc.proxy.wp.newPost(123, 'my_user', 'my_passwd', {
        'post_type': 'post',
        'post_status': 'publish',
        'post_title': 'New blog post',
        'post_content': """\
New blog post: World Series 2010 <a href="http://bit.ly/9HrEU5">http://bit.ly/9HrEU5</a><p class="fb-tags"></p><p class="fb-via">\n<a href="http://facebook.com/permalink.php?id=tag:facebook.com,2012:212038&story_fbid=124561947600007">via Facebook</a>\n</p>""",
        'post_date': datetime.datetime(2010, 10, 28, 00, 04, 03),
        'comment_status': 'open',
        'terms_names': {'post_tag': social_to_wordpress.POST_TAGS},
        }).AndReturn(post_id)
    self.xmlrpc.proxy.wp.newComment(123, '', '', post_id, {
        'author': 'Ron Ald',
        'author_url': 'http://facebook.com/513046677',
        'content': """New blog: You're awesome.
<cite><a href="http://facebook.com/212038/posts/124561947600007?comment_id=672819">via Facebook</a></cite>""",
        })

    self.mox.ReplayAll()
    social_to_wordpress.post_to_wordpress(self.xmlrpc, {
      "id": "212038_124561947600007",
      "from": {
        "name": "Ryan Barrett",
        "id": "212038"
      },
      "message": "New blog post: World Series 2010 http://bit.ly/9HrEU5",
      "type": "status",
      "status_type": "mobile_status_update",
      "application": {
        "name": "foo bar",
        "id": "131732509879"
      },
      "created_time": "2010-10-28T00:04:03+0000",
      "updated_time": "2010-10-28T00:23:04+0000",
      "comments": {
        "data": [
          {
            "id": "212038_124561947600007_672819",
            "from": {
              "name": "Ron Ald",
              "id": "513046677"
            },
            "message": "New blog: You're awesome.",
            "created_time": "2010-10-28T00:23:04+0000"
          }
        ],
        "count": 1
      }
    })