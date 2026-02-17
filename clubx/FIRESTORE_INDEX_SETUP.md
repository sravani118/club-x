# Firestore Indexes for Join Requests

## Required Composite Index

For the Join Requests functionality, you need to create a composite index in Firestore:

### Index Configuration:

**Collection**: `clubJoinRequests`

**Fields**:
1. `clubId` - Ascending
2. `status` - Ascending  
3. `requestedAt` - Descending

### How to Create:

#### Option 1: Via Firebase Console
1. Go to Firebase Console → Firestore Database → Indexes
2. Click "Create Index"
3. Select collection: `clubJoinRequests`
4. Add fields in order:
   - `clubId` (Ascending)
   - `status` (Ascending)
   - `requestedAt` (Descending)
5. Click "Create"

#### Option 2: Via firestore.indexes.json
Add this to your `firestore.indexes.json` file:

```json
{
  "indexes": [
    {
      "collectionGroup": "clubJoinRequests",
      "queryScope": "COLLECTION",
      "fields": [
        {
          "fieldPath": "clubId",
          "order": "ASCENDING"
        },
        {
          "fieldPath": "status",
          "order": "ASCENDING"
        },
        {
          "fieldPath": "requestedAt",
          "order": "DESCENDING"
        }
      ]
    }
  ]
}
```

#### Option 3: Automatic (Recommended)
When you first run the app and open the Join Requests screen, Firestore will throw an error with a direct link to create the index. Simply click the link and the index will be created automatically.

### Note:
Index creation can take a few minutes. The screen will work once the index is built.
