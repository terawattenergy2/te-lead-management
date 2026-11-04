export const leadFields = [
  "Requirement",
  "System Size",
  "GPS",
  "Partner ID",
  "Partner Company",
  "Partner Email",
  "Status",
  "Assigned At",
  "Confirmed At",
  "Last Update",
  "Reminder Sent At",
  "Recall At",
];
export const dateFields = leadFields.filter(
  (x) => x.endsWith(" At") || x === "Last Update",
);
