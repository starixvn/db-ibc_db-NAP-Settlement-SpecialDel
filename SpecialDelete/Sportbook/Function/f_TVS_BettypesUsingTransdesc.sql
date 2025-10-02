/*<info serverAlias="DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02" executers="" viewers="" isFunction="1"></info>*/
ALTER FUNCTION [dbo].[f_TVS_BettypesUsingTransdesc] ()
RETURNS TABLE
AS
/*
    Created: 20240726@Max
    Task: Add list bettypes using transdesc column [Redmine: #197051]
	DB: DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02

    Revisions:
		- 20240726@Max: Create function [Redmine: #197051]
		- 20250311@July: Add alias server [Redmine: #217771]
		- 20250908@Lani: [TVS] Basketball AIO - Integrate new bet types for Basketball Player Props + refactor code CI/CD [Redmine: #234941]
		
    Parameters Explanation:    
		TypeId = 0 ;single player
			   = 1 ;player and odds
*/

RETURN (
	WITH CteBettype AS (
		-- Goal - Home (TypeId = 0)
		SELECT Bettype, TypeId FROM (VALUES 
			(9650, 0), (9651, 0), (9652, 0), (9653, 0), (9654, 0), (9655, 0), (9656, 0), (9657, 0), (9658, 0), (9659, 0), (9660, 0), (9661, 0),
			(9668, 0), (9669, 0), (9670, 0), (9671, 0), (9672, 0), (9673, 0), (9674, 0), (9675, 0), (9676, 0), (9677, 0), (9678, 0), (9679, 0),
			(9680, 0), (9681, 0), (9682, 0), (9683, 0), (9684, 0), (9685, 0), (9686, 0), (9687, 0), (9688, 0), (9689, 0), (9690, 0), (9691, 0),
			(9692, 0), (9693, 0), (9694, 0), (9695, 0), (9696, 0), (9697, 0), (9698, 0), (9699, 0), (9702, 0), (9703, 0), (9704, 0), (9705, 0),
			(9712, 0), (9713, 0), (9714, 0), (9715, 0), (9716, 0), (9717, 0), (9718, 0), (9719, 0), (9720, 0), (9721, 0), (9730, 0), (9731, 0),
			(9732, 0), (9733, 0), (9734, 0), (9735, 0), (9736, 0), (9737, 0), (9738, 0), (9739, 0),
			(653, 0), (654, 0), (655, 0), (656, 0), (657, 0), (658, 0), (659, 0), (660, 0), (661, 0), (662, 0), (663, 0), (664, 0),
			(665, 0), (666, 0), (667, 0), (668, 0), (669, 0), (670, 0), (671, 0), (672, 0), (673, 0), (674, 0), (675, 0), (676, 0),
			(677, 0), (678, 0), (679, 0), (685, 0), (686, 0), (687, 0), (688, 0)
		) AS PlayerGroup(Bettype, TypeId)
		
		UNION ALL
		
		-- Group player & odds (TypeId = 1)
		SELECT Bettype, TypeId FROM (VALUES 
			(9662, 1), (9663, 1), (9664, 1), (9665, 1), (9666, 1), (9667, 1),
			(680, 1), (681, 1), (682, 1), (683, 1), (684, 1)
		) AS PlayerAndOddsGroup(Bettype, TypeId)
	)
	SELECT CONVERT(SMALLINT, Bettype) AS Bettype, CONVERT(TINYINT, TypeId) AS TypeId
	FROM CteBettype
)
GO
