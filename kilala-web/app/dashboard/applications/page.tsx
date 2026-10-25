import { redirect } from "next/navigation";

// "Applications" was dropped — businesses auto-accredit on registration
// (business_profiles.is_accredited defaults TRUE), so there's no approve/deny
// queue. Business accreditation now lives under Businesses.
export default function ApplicationsPage() {
  redirect("/dashboard/businesses");
}
