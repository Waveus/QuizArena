const { onCall, HttpsError } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");
const logger = require("firebase-functions/logger");

admin.initializeApp();

exports.handleFriendRequest = onCall(async (request) => {

    if (!request.auth) { 
        logger.error("No auth");
        throw new HttpsError('unauthenticated', 'Reauth required');
    }

    const { senderId, action } = request.data;
    const currentUserId = request.auth.uid;
    const timestamp = admin.firestore.FieldValue.serverTimestamp(); 
    
    if (!senderId) {
        logger.warn("No senderId");
        throw new HttpsError('invalid-argument', 'No sender id provided');
    }
    
    if (action !== 'accept' && action !== 'reject') {
        logger.warn(`Invalid action: ${action}`);
        throw new HttpsError('invalid-argument', 'Action must be accept or reject.');
    }

    try {
        const db = admin.firestore();
        let message = '';
        
        await db.runTransaction(async (transaction) => {
            const requestRef = db.collection('friend_request').doc(`${senderId}_${currentUserId}`);
            const requestDoc = await transaction.get(requestRef);

            if (!requestDoc.exists) {
                logger.warn(`Request ${senderId} to ${currentUserId} does not exist`);
                throw new HttpsError('not-found', 'Friend request does not exist');
            }

            if (action === 'accept') {
                const currentUserFriendDocRef = db.collection('user_data').doc(currentUserId)
                                                .collection('friends').doc(senderId); 
                const senderFriendDocRef = db.collection('user_data').doc(senderId)
                                             .collection('friends').doc(currentUserId);
                                             
                transaction.set(currentUserFriendDocRef, { addedAt: timestamp });
                transaction.set(senderFriendDocRef, { addedAt: timestamp });
                
                message = "Accepted successfully";
                
            } else if (action === 'reject') {
                message = "Rejected successfully";
            }
            
            transaction.delete(requestRef);
            
            logger.info(`${message}: ${senderId} -> ${currentUserId}`);
        });

        return { success: true, message: message };

    } catch (error) {
        if (error instanceof HttpsError) {
            throw error;
        }
        logger.error("Server error unhandled", error);
        throw new HttpsError('internal', 'Internal server error.', error.toString());
    }
});

exports.sendFriendRequest = onCall(async (request) => {
    if (!request.auth) { 
        logger.error("Brak uwierzytelnienia użytkownika.");
        throw new HttpsError('unauthenticated', 'Wymagane uwierzytelnienie.');
    }

    const { receiverId } = request.data;
    const senderId = request.auth.uid;
    
    if (!receiverId) {
        throw new HttpsError('invalid-argument', 'No ID of friend');
    }

    if (senderId === receiverId) {
        throw new HttpsError('invalid-argument', 'You cannot send data to yourself');
    }

    try {
        const db = admin.firestore();
        await db.runTransaction(async (transaction) => {
            
            const requestDocRef1 = db.collection('friend_request').doc(`${senderId}_${receiverId}`);
            const requestDocRef2 = db.collection('friend_request').doc(`${receiverId}_${senderId}`);
            
            const doc1 = await transaction.get(requestDocRef1);
            const doc2 = await transaction.get(requestDocRef2);

            if (doc1.exists || doc2.exists) {
                throw new HttpsError('already-exists', 'Request was already sent');
            }

            const friendsDocRef = db.collection('user_data').doc(senderId)
                                      .collection('friends').doc(receiverId);
            const friendsDoc = await transaction.get(friendsDocRef);

            if (friendsDoc.exists) {
                throw new HttpsError('already-exists', 'You are friends already');
            }

            transaction.set(requestDocRef1, {
                sender: senderId,
                receiver: receiverId,
            });
        });

        return { success: true, message: "Request send successfully" };

    } catch (error) {
        if (error instanceof HttpsError) {
            throw error;
        }
        throw new HttpsError('internal', 'Internal error', error.toString());
    }
});