import { redirect } from "next/navigation";
import { getCurrentUser } from "@/lib/session";
import { ALLOWED_ROLE } from "@/lib/token";

export default async function Home() {
  const user = await getCurrentUser();
  redirect(user?.role === ALLOWED_ROLE ? "/dashboard" : "/login");
}
