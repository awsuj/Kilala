import { getCurrentUser } from "@/lib/session";
import SettingsForms from "./SettingsForms";

export default async function SettingsPage() {
  const user = await getCurrentUser();
  return <SettingsForms email={user?.email ?? ""} />;
}
