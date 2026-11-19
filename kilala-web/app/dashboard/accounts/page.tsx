import { getLgus } from "@/lib/lgus";
import { ApiError } from "@/lib/api";
import CreateAccountDialog from "./CreateAccountDialog";
import {
  Card,
  CardHeader,
  CardTitle,
  CardDescription,
  CardContent,
} from "@/components/ui/card";

export default async function AccountsPage() {
  let lgus;
  try {
    lgus = await getLgus();
  } catch (e) {
    const msg =
      e instanceof ApiError ? e.message : "Could not reach the server.";
    return (
      <Card>
        <CardHeader>
          <CardTitle>Accounts</CardTitle>
          <CardDescription className="text-destructive">
            Couldn&apos;t load city list: {msg}
          </CardDescription>
        </CardHeader>
        <CardContent />
      </Card>
    );
  }

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-bold">Accounts</h1>
        <CreateAccountDialog lgus={lgus} />
      </div>
    </div>
  );
}
