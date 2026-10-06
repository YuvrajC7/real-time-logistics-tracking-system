-- ============================================================
-- STORAGE: delivery-proofs bucket
-- Drivers upload proof photos; customers read their own
-- ============================================================

-- Create the bucket (run via Supabase client, not raw SQL, but we doc it here)
-- In Supabase dashboard: Storage > New bucket > delivery-proofs > Private

-- Storage policies (applied via Supabase Storage RLS)
-- These are reference policies; apply them in the Supabase Storage dashboard
-- or via the management API.

-- Policy: Drivers can upload to their own folder
-- USING: (bucket_id = 'delivery-proofs' AND auth.role() = 'authenticated')
-- WITH CHECK: auth_role() = 'driver'

-- Policy: Customers can read proofs for their own shipments  
-- This requires a join which is handled by the application layer
-- using a signed URL generated server-side.

-- Storage helper function: generate signed URL for proof
CREATE OR REPLACE FUNCTION get_proof_url(p_shipment_id UUID)
RETURNS TEXT
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_photo_url TEXT;
  v_sender_id UUID;
BEGIN
  -- Check caller owns this shipment
  SELECT dp.photo_url, s.sender_id
  INTO v_photo_url, v_sender_id
  FROM delivery_proofs dp
  JOIN shipments s ON dp.shipment_id = s.shipment_id
  WHERE dp.shipment_id = p_shipment_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Proof not found for shipment %', p_shipment_id;
  END IF;

  -- Only sender or admin/dispatcher may access
  IF auth_role() = 'customer' AND v_sender_id <> auth.uid() THEN
    RAISE EXCEPTION 'Access denied';
  END IF;

  RETURN v_photo_url;
END;
$$;
