-- A public avatar can be viewed by URL, but only its owner can manage the object.
create policy candidate_photo_select_own on storage.objects
  for select to authenticated
  using (bucket_id = 'profile-photos' and
    name ~ ('^' || (select auth.uid())::text || '/avatar[.](jpg|jpeg|png|webp)$'));

create policy candidate_photo_insert_own on storage.objects
  for insert to authenticated
  with check (bucket_id = 'profile-photos' and
    name ~ ('^' || (select auth.uid())::text || '/avatar[.](jpg|jpeg|png|webp)$'));

create policy candidate_photo_update_own on storage.objects
  for update to authenticated
  using (bucket_id = 'profile-photos' and
    name ~ ('^' || (select auth.uid())::text || '/avatar[.](jpg|jpeg|png|webp)$'))
  with check (bucket_id = 'profile-photos' and
    name ~ ('^' || (select auth.uid())::text || '/avatar[.](jpg|jpeg|png|webp)$'));

create policy candidate_photo_delete_own on storage.objects
  for delete to authenticated
  using (bucket_id = 'profile-photos' and
    name ~ ('^' || (select auth.uid())::text || '/avatar[.](jpg|jpeg|png|webp)$'));
