import XCTest
@testable import pirate

final class ModelDecodingTests: XCTestCase {
    func testCommunityPreviewDecodesFlatPayloadWithLossyFields() throws {
        let data = """
        {
          "community_id": 123,
          "display_name": 456,
          "route_slug": "shipyard",
          "membership_mode": "open",
          "allow_anonymous_identity": "true",
          "allow_qualifiers_on_anonymous_posts": false,
          "member_count": "42",
          "follower_count": 7.8,
          "created": "2026-05-20T10:00:00Z",
          "human_verification_lane": 99,
          "reference_links": [
            {
              "id": 77,
              "platform": "site",
              "label": 88,
              "url": "https://example.com",
              "position": "2",
              "verified": "true"
            }
          ],
          "rules": [
            {
              "id": 5,
              "title": 100,
              "position": "1"
            }
          ],
          "moderators": [
            {
              "user": 321,
              "display_name": 654,
              "role": "owner"
            }
          ],
          "flair_policy": {
            "flair_enabled": "true",
            "definitions": [
              {
                "id": 11,
                "label": "Question",
                "position": "3"
              }
            ]
          },
          "viewer_following": "false"
        }
        """.data(using: .utf8)!

        let preview = try JSONDecoder().decode(CommunityPreview.self, from: data)

        XCTAssertEqual(preview.community.communityId, "123")
        XCTAssertEqual(preview.community.displayName, "456")
        XCTAssertEqual(preview.community.routeSlug, "shipyard")
        XCTAssertEqual(preview.community.allowAnonymousIdentity, true)
        XCTAssertEqual(preview.community.allowQualifiersOnAnonymousPosts, false)
        XCTAssertEqual(preview.community.memberCount, 42)
        XCTAssertEqual(preview.community.followerCount, 7)
        XCTAssertEqual(preview.community.createdAt, "2026-05-20T10:00:00Z")
        XCTAssertEqual(preview.humanVerificationLane, "99")
        XCTAssertEqual(preview.referenceLinks?.first?.communityReferenceLinkId, "77")
        XCTAssertEqual(preview.referenceLinks?.first?.label, "88")
        XCTAssertEqual(preview.referenceLinks?.first?.position, 2)
        XCTAssertEqual(preview.referenceLinks?.first?.verified, true)
        XCTAssertEqual(preview.rules?.first?.ruleId, "5")
        XCTAssertEqual(preview.rules?.first?.title, "100")
        XCTAssertEqual(preview.rules?.first?.position, 1)
        XCTAssertEqual(preview.moderators.first?.user, "321")
        XCTAssertEqual(preview.moderators.first?.displayName, "654")
        XCTAssertEqual(preview.flairPolicy?.flairEnabled, true)
        XCTAssertEqual(preview.flairPolicy?.definitions.first?.flairId, "11")
        XCTAssertEqual(preview.flairPolicy?.definitions.first?.position, 3)
        XCTAssertEqual(preview.viewerFollowing, false)
    }

    func testPostDecodesAliasesAndLossyFields() throws {
        let data = """
        {
          "id": 987,
          "community": 123,
          "title": 555,
          "link_og_title": "OG title",
          "link_og_description": 808,
          "og_image": "https://example.com/card.png",
          "embeds": [
            { "provider": "site", "count": 4 }
          ],
          "media_refs": [
            {
              "media_key": 44,
              "media_type": "image",
              "size_bytes": "1024",
              "width": 640.9
            }
          ],
          "author_user": 777,
          "identity_mode": "anonymous",
          "anonymous_label": 12,
          "label_id": 999,
          "score": "8",
          "upvote_count": 5.9,
          "comment_count": "3",
          "created": "2026-05-20T11:00:00Z"
        }
        """.data(using: .utf8)!

        let post = try JSONDecoder().decode(Post.self, from: data)

        XCTAssertEqual(post.postId, "987")
        XCTAssertEqual(post.communityId, "123")
        XCTAssertEqual(post.title, "555")
        XCTAssertEqual(post.linkTitle, "OG title")
        XCTAssertEqual(post.linkDescription, "808")
        XCTAssertEqual(post.linkImage, "https://example.com/card.png")
        XCTAssertEqual(post.embeds?.first?.firstStringValue(named: "provider"), "site")
        XCTAssertEqual(post.mediaRefs?.first?.mediaKey, "44")
        XCTAssertEqual(post.mediaRefs?.first?.sizeBytes, 1024)
        XCTAssertEqual(post.mediaRefs?.first?.width, 640)
        XCTAssertEqual(post.authorUserId, "777")
        XCTAssertEqual(post.authorIdentityMode, "anonymous")
        XCTAssertEqual(post.authorAnonymousLabel, "12")
        XCTAssertEqual(post.flairId, "999")
        XCTAssertEqual(post.score, 8)
        XCTAssertEqual(post.upvoteCount, 5)
        XCTAssertEqual(post.commentCount, 3)
        XCTAssertEqual(post.createdAt, "2026-05-20T11:00:00Z")
    }

    func testVoteResponsesDecodeBackendIdentifiers() throws {
        let postVoteData = """
        {
          "post": "post_123",
          "value": 1
        }
        """.data(using: .utf8)!

        let commentVoteData = """
        {
          "comment": "cmt_456",
          "value": -1
        }
        """.data(using: .utf8)!

        let postVote = try JSONDecoder().decode(PostVoteResponse.self, from: postVoteData)
        let commentVote = try JSONDecoder().decode(CommentVoteResponse.self, from: commentVoteData)

        XCTAssertEqual(postVote.id, "post_123")
        XCTAssertEqual(postVote.value, 1)
        XCTAssertEqual(commentVote.id, "cmt_456")
        XCTAssertEqual(commentVote.value, -1)
    }

    func testUserAndProfileDecodeSessionFacingFields() throws {
        let userData = """
        {
          "id": 42,
          "created": "2026-05-20T12:00:00Z",
          "verification_state": 1,
          "capability_provider": "very",
          "verified_at": "2026-05-20T12:05:00Z"
        }
        """.data(using: .utf8)!

        let profileData = """
        {
          "id": 42,
          "display_name": 1234,
          "bio": true,
          "avatar_ref": "https://example.com/avatar.png",
          "global_handle": {
            "id": "global-1",
            "label": "captain",
            "tier": "founder",
            "status": "active"
          },
          "linked_handles": [
            {
              "linked_handle": "handle-1",
              "label": "captain",
              "kind": "global",
              "metadata": { "score": 12, "active": true }
            }
          ],
          "primary_wallet_address": "0xabc",
          "follower_count": "21",
          "following_count": 4.7,
          "preferred_locale": "en-US"
        }
        """.data(using: .utf8)!

        let user = try JSONDecoder().decode(User.self, from: userData)
        let profile = try JSONDecoder().decode(Profile.self, from: profileData)

        XCTAssertEqual(user.userId, "42")
        XCTAssertEqual(user.createdAt, "2026-05-20T12:00:00Z")
        XCTAssertEqual(user.verificationState, "1")
        XCTAssertEqual(user.capabilityProvider, "very")
        XCTAssertEqual(user.verifiedAt, "2026-05-20T12:05:00Z")
        XCTAssertEqual(profile.userId, "42")
        XCTAssertEqual(profile.displayName, "1234")
        XCTAssertEqual(profile.bio, "true")
        XCTAssertEqual(profile.avatarRef, "https://example.com/avatar.png")
        XCTAssertEqual(profile.globalHandle?.label, "captain")
        XCTAssertEqual(profile.linkedHandles?.first?.metadata?["score"]?.intValue, 12)
        XCTAssertEqual(profile.linkedHandles?.first?.metadata?["active"]?.boolValue, true)
        XCTAssertEqual(profile.primaryWalletAddress, "0xabc")
        XCTAssertEqual(profile.followerCount, 21)
        XCTAssertEqual(profile.followingCount, 4)
        XCTAssertEqual(profile.preferredLocale, "en-US")
    }

    func testNotificationEventAndUserTaskDecodeJSONValuePayloads() throws {
        let eventData = """
        {
          "id": 500,
          "type": "post.created",
          "actor_user_id": 42,
          "subject_type": "post",
          "subject": 987,
          "object_type": "community",
          "payload": {
            "post_id": "post-1",
            "count": 12,
            "nested": { "href": "https://example.com/post-1" }
          },
          "created": "2026-05-20T13:00:00Z"
        }
        """.data(using: .utf8)!

        let taskData = """
        {
          "id": 600,
          "object": "task",
          "user": 42,
          "type": "review",
          "subject_type": "community",
          "subject": 123,
          "status": "open",
          "priority": "9",
          "payload": {
            "reason": "verify",
            "eligible": true
          },
          "created": "2026-05-20T14:00:00Z"
        }
        """.data(using: .utf8)!

        let event = try JSONDecoder().decode(NotificationEvent.self, from: eventData)
        let task = try JSONDecoder().decode(UserTask.self, from: taskData)

        XCTAssertEqual(event.id, "500")
        XCTAssertEqual(event.actorUserId, "42")
        XCTAssertEqual(event.subject, "987")
        XCTAssertEqual(event.payload?["post_id"]?.stringValue, "post-1")
        XCTAssertEqual(event.payload?["count"]?.intValue, 12)
        XCTAssertEqual(event.payload?["nested"]?.firstStringValue(named: "href"), "https://example.com/post-1")
        XCTAssertEqual(task.id, "600")
        XCTAssertEqual(task.objectType, "task")
        XCTAssertEqual(task.userId, "42")
        XCTAssertEqual(task.subject, "123")
        XCTAssertEqual(task.priority, 9)
        XCTAssertEqual(task.payload?["reason"]?.stringValue, "verify")
        XCTAssertEqual(task.payload?["eligible"]?.boolValue, true)
    }
}
