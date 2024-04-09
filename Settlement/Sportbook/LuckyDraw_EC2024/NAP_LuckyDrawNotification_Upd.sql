/*<info serverAlias="DBCTG-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE NAP_LuckyDrawNotification_Upd
	@DrawIDList	VARCHAR(MAX)	= ''
AS
/*	
	Created: 20240327@Louisa
    Task: EC 2024-Correct Score Sharing and Lucky Draw-(Pool prize) [Redmine:#202309]
	DB: DBCTG'bodb02

	Revision: 20240327@Louisa initial [Redmine:#202309]
*/
BEGIN
	DECLARE @tmp_DrawID TABLE (DrawID INT)
	INSERT INTO @tmp_DrawID (DrawID)
	SELECT f.value FROM STRING_SPLIT(@DrawIDList, ',') f

	IF ISNULL(@DrawIDList,'') = ''
	RETURN

	UPDATE l
	SET l.IsNotiFy = 1
	FROM dbo.LuckyDrawList l 
		INNER JOIN @tmp_DrawID t
			ON l.DrawID = t.DrawID

END
GO
