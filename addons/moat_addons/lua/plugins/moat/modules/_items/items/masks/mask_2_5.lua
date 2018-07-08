ITEM.Name = "Crown Hockey Mask"
ITEM.ID = 427
ITEM.Description = "This does not make you the new Queen of England."
ITEM.Rarity = 4
ITEM.Collection = "Urban Style Collection"
ITEM.Skin = 5
ITEM.Model = "models/sal/acc/fix/mask_2.mdl"
ITEM.Attachment = "eyes"



function ITEM:ModifyClientsideModel(ply, model, pos, ang)

	model:SetSkin( 5 )
	model:SetModelScale( 1.1, 0 )
	pos = pos + (ang:Forward() * -4.216187) + (ang:Right() * 0.022186) +  (ang:Up() * -0.913788)
	
	return model, pos, ang
end

