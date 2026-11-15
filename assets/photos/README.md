# Photos

The same photos the website uses (`frontend/public/photos/` in the AgriLink_SriLanka repository),
so a crop or a page looks the same in both.

- `crops/`: one photo per crop type, named like the crop (`green-gram.webp` for "Green Gram").
  `other.webp` is for crops without their own photo. Picked by `cropPhotoAsset()` in
  `lib/shared/media/crop_photos.dart`.
- `scenes/`: Sri Lankan fields, markets and farm work, for page banners and the sign-in screen
  (`Scenes` in the same file).

All are from Unsplash and free to use under the Unsplash licence, which needs no credit. The
photographer and original link for each one are recorded in the website's
`frontend/src/lib/cropPhotos.ts`.

To add a crop photo: add it here as WebP (about 1200 px wide), give it the crop's name in
kebab case, and add the same photo to the website.
