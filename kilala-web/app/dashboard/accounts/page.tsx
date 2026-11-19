import { getLgus, getLguAdmins, type LguAdmin } from "@/lib/lgus";
import { ApiError } from "@/lib/api";
import CreateAccountDialog from "./CreateAccountDialog";
import {
  Card,
  CardHeader,
  CardTitle,
  CardDescription,
  CardContent,
} from "@/components/ui/card";
import {
  Table,
  TableHeader,
  TableBody,
  TableRow,
  TableHead,
  TableCell,
} from "@/components/ui/table";
import { Badge } from "@/components/ui/badge";

export default async function AccountsPage() {
  // The dialog needs the city list; the table needs the existing accounts.
  // Fetch both, but don't let a failure on one blank the whole page.
  const [lgusRes, adminsRes] = await Promise.allSettled([
    getLgus(),
    getLguAdmins(),
  ]);

  if (lgusRes.status === "rejected") {
    const e = lgusRes.reason;
    const msg = e instanceof ApiError ? e.message : "Could not reach the server.";
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

  const lgus = lgusRes.value;
  const admins: LguAdmin[] =
    adminsRes.status === "fulfilled" ? adminsRes.value : [];
  const adminsError =
    adminsRes.status === "rejected"
      ? adminsRes.reason instanceof ApiError
        ? adminsRes.reason.message
        : "Could not reach the server."
      : null;

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-bold">Accounts</h1>
        <CreateAccountDialog lgus={lgus} />
      </div>

      <Card>
        <CardHeader>
          <CardTitle>LGU Admin Accounts</CardTitle>
          <CardDescription>
            {admins.length} account{admins.length === 1 ? "" : "s"} · portal
            users who can register cardholders and accredit businesses
          </CardDescription>
        </CardHeader>
        <CardContent>
          {adminsError ? (
            <p className="rounded-md bg-destructive/10 px-3 py-2 text-sm text-destructive">
              Couldn&apos;t load accounts: {adminsError}
            </p>
          ) : admins.length === 0 ? (
            <p className="py-8 text-center text-sm text-muted-foreground">
              No LGU admin accounts yet. Create one with the button above.
            </p>
          ) : (
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Name</TableHead>
                  <TableHead>Email</TableHead>
                  <TableHead>City</TableHead>
                  <TableHead>Department</TableHead>
                  <TableHead>Status</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {admins.map((a) => (
                  <TableRow key={a.id}>
                    <TableCell className="font-bold text-foreground">
                      {a.first_name} {a.last_name}
                      {a.position && (
                        <span className="block text-xs font-normal text-muted-foreground">
                          {a.position}
                        </span>
                      )}
                    </TableCell>
                    <TableCell className="font-mono text-xs text-muted-foreground">
                      {a.email}
                    </TableCell>
                    <TableCell>{a.municipality_name}</TableCell>
                    <TableCell className="text-muted-foreground">
                      {a.department}
                    </TableCell>
                    <TableCell>
                      {a.is_active ? (
                        <Badge variant="secondary">Active</Badge>
                      ) : (
                        <Badge variant="outline" className="text-muted-foreground">
                          Inactive
                        </Badge>
                      )}
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          )}
        </CardContent>
      </Card>
    </div>
  );
}
