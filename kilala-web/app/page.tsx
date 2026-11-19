import { redirect } from "next/navigation";
import { getCurrentUser } from "@/lib/session";
import { isAllowedRole, landingPathForRole } from "@/lib/token";

export default async function Home() {
  const user = await getCurrentUser();
  redirect(isAllowedRole(user?.role) ? landingPathForRole(user?.role) : "/login");
}
