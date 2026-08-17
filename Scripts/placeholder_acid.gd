class_name PlaceholderAcid
extends RefCounted

const BODY := Color("6aaa22")
const BODY_DARK := Color("3d6a12")
const SURFACE := Color("c6e04a")
const BORDER := Color("24380a")


static func create_texture(size: Vector2i) -> ImageTexture:
	var image := Image.create(maxi(size.x, 2), maxi(size.y, 2), false, Image.FORMAT_RGBA8)
	for y in size.y:
		var t := float(y) / float(maxi(size.y - 1, 1))
		var fill := BODY.lerp(BODY_DARK, t)
		for x in size.x:
			var pixel := fill
			if y <= 2:
				pixel = SURFACE
			elif ((x + y) % 10) == 0:
				pixel = fill.lightened(0.12)
			if x == 0 or y == 0 or x == size.x - 1 or y == size.y - 1:
				pixel = BORDER
			image.set_pixel(x, y, pixel)
	return ImageTexture.create_from_image(image)
