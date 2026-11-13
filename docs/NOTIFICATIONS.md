# Notifications screen

The bell icon opens a full-screen notifications inbox on Android. It reads the latest 100 documents from `users/{uid}/notifications`, ordered by `createdAt` (newest first). Each document may contain:

| Field | Type | Purpose |
| --- | --- | --- |
| `title` | string | Short heading |
| `body` | string | Message text |
| `type` | string | `application`, `job`, `interview`, or `general` for the icon |
| `createdAt` | Firestore timestamp | Sort order and displayed time |
| `readAt` | Firestore timestamp, optional | Present when the user has read it |

Publish the updated [`firestore.rules`](../firestore.rules) in Firebase Console before using this screen. Only the recipient can read their notifications and mark them as read. Client apps cannot create or edit notification content; a trusted backend using Firebase Admin must create those documents.

No notification-producing backend events or Android push notifications are connected yet. Until a trusted backend creates notification documents, the screen displays its empty state. The screen does not show sample alerts as if they were real account events.
