# Ad Gallery access for custom roles

## Goal

Allow every authenticated account member with a custom role, such as Vendedores, to see and open the Ad Gallery. Keep the ad performance report under its existing authorization rules.

## Current behavior

The Ad Gallery route accepts only the `administrator` and `agent` permissions. Enterprise account users assigned to a custom role receive `custom_role` plus their granular permissions, so the frontend hides the navigation entry and rejects direct navigation even though the gallery endpoint already permits authenticated account members.

## Design

Add `custom_role` to the existing `meta.permissions` list for the `crm_ad_gallery` route. The sidebar and router already use this route metadata as their shared authorization source, so this single change enables both menu visibility and direct route access.

Do not change the gallery endpoint, role models, database, or the `crm_ad_reports` route. This preserves the existing distinction between broadly available sales reference material and restricted performance reporting.

## Acceptance criteria

- Administrators can see and open the Ad Gallery.
- Standard agents can see and open the Ad Gallery.
- Users assigned to any custom role can see and open the Ad Gallery, regardless of its granular permission set.
- The ad performance report retains its current authorization behavior.
- The modified route file passes the repository's frontend lint checks.

## Rollout

Build and deploy the same application image used by the web and worker services through the existing production deployment process. After deployment, verify service convergence and application health, then confirm the route metadata in the deployed asset or exercise the Gallery with a custom-role account when such a session is available.

## Rollback

Revert the route metadata change and redeploy the preceding application image. No data rollback is required.
