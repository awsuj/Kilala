import express, { Request, Response } from 'express';
import cors from 'cors';
import dotenv from 'dotenv';

dotenv.config();

const app = express();
const PORT = process.env.PORT || 5000;

app.use(cors());
app.use(express.json());

app.get('/api/health', (req: Request, res: Response) => {
  res.status(200).json({ status: 'healthy', system: 'Kilala Backend API' });
});

app.listen(PORT, () => {
  console.log(`[server]: Kilala backend running on port ${PORT}`);
});