# INC-0101 - VPN Client Fails to Authenticate After Certificate Rotation

## Summary
Remote users were unable to connect after a planned certificate update on the VPN gateway.

## Impact
About 20 remote employees could not establish a secure tunnel for 35 minutes.

## Actions
- Confirmed the new certificate chain on the gateway.
- Compared trust store versions on affected laptops.
- Reissued the client profile package with the updated intermediate certificate.
- Logged the workaround and validation steps in the worklog.

## Resolution
Authentication succeeded after users imported the updated profile. A KB article and change checklist were added to prevent recurrence.
