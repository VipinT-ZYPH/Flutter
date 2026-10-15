import * as functions from 'firebase-functions';
import { verifyToken } from './middleware/auth';
import { ai } from './ai/gemini';

export const generateReflection = functions.https.onRequest(async (req, res) => {
  try {
    const uid = await verifyToken(req);
    const { journalId, prompt } = req.body;

    const journalRef = admin.firestore().collection('users').doc(uid).collection('journals').doc(journalId);
    const journalDoc = await journalRef.get();

    if (!journalDoc.exists) {
      res.status(404).json({ error: 'Journal not found' });
      return;
    }

    const journalData = journalDoc.data();
    
    const response = await ai.models.generateContent({
      model: "gemini-3.8-flash",
      contents: `Journal entry: ${journalData?.title}\n\n${journalData?.content}\n\nAct as an empathetic journal reflection assistant. Provide a short, constructive reflection based on this entry.`,
    });

    res.json({ reflection: response.text });
  } catch (error) {
    res.status(500).json({ error: 'Failed to generate reflection' });
  }
});
