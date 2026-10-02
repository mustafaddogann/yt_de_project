-- Administrator-only Synthetic Security Demonstration. Never joined to analytical models.
MERGE `{{ params.project }}.security_demo.synthetic_contacts` t
USING (SELECT 'synthetic-channel-1' channel_key, 'Example Contact' contact_name,
 'mustafa@example.com' contact_email, '+1-202-555-0100' contact_phone) s
ON t.channel_key=s.channel_key
WHEN NOT MATCHED THEN INSERT ROW;
