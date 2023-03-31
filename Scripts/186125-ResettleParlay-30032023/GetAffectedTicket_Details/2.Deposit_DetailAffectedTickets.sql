/*	
	Creator: Tina
	Date: 20230330
	DB: DBDWCSS/bodb02_20230329
	[Redmine:#186125]

*/

CREATE TABLE #result (transid BIGINT)

--- Deposit sportsbook --commission --group 1
--single ticket
INSERT INTO #result (transid)
SELECT bt.transid
FROM bettrans bt  with (nolock)
join match m with (nolock) on bt.matchid = m.matchid
join dbo.Dep_CustSettingMode dcm with (nolock) on dcm.custid = bt.custid
left join dbo.Dep_CustDiscountSetting_Member dcom with (nolock)  on dcom.custid = bt.custid and dcom.sporttype =1 and dcom.bettype=1 
left join dbo.Dep_CustDiscountGroupSetting_Member gdcom with (nolock) on gdcom.agentid = bt.recommend and gdcom.sporttype =1 and gdcom.bettype=1 
where 1 = case when dcm.isGroupedComm = 1 then 
				case when 	gdcom.playerdiscount <> bt.playerdiscount or
						 	gdcom.agentdiscount <> bt.discount or
						 	gdcom.masterdiscount <> bt.adiscount or
						 	gdcom.superdiscount <>  bt.sdiscount then 1 
				else 0 end 
				else
				case when bt.playerdiscount <> dcom.playerdiscount or
				          bt.discount <> dcom.agentdiscount or
				          bt.adiscount <> dcom.masterdiscount or
						  bt.sdiscount <> dcom.superdiscount then 1 
				else 0 end
				end
and bt.transdate between '20230330 04:00' and '20230330 04:20'
and bt.bettype in (1, 2, 3, 7, 8, 11, 12, 13, 17, 18, 25, 27, 28, 121, 122, 123, 128, 153, 155, 156, 157, 178, 183, 184, 185,
            189, 190, 191, 194, 197, 198, 203, 204, 205, 206, 207, 208, 209, 219, 220, 228, 229, 381, 382, 383, 386,
            387, 388, 389, 390, 393, 394, 400, 401, 402, 403, 404, 411, 428, 453, 461, 462, 463, 464, 470, 471, 472,
            477, 478, 482, 483, 484, 485, 488, 489, 490, 491, 492, 497, 609, 610, 611, 615, 616, 701, 702, 704, 705,
            706, 708, 709, 710, 801, 803, 804, 805, 806, 1318, 3902, 3904, 3905, 3906, 3907, 3908, 7901, 9002, 9003,
            9005, 9008, 9009, 9012, 9013, 9018, 9019, 9024, 9025, 9028, 9029, 9034, 9035, 9040, 9041, 9046, 9047, 9052,
            9053, 9058, 9059, 9060, 9061, 9070, 9071, 9074, 9076, 9077, 9078, 9079, 9080, 9081, 9082, 9083, 9084, 9085,
            9086, 9089, 9090, 9091, 9092, 9093, 9094, 9095, 9096, 9097, 9098, 9099, 9100, 9116, 9117, 9118, 9119, 9120,
            9121, 9123, 9126, 9127, 9128, 9129, 9131, 9134, 9136, 9137, 9139, 9140, 9402, 9403, 9404, 9405, 9406, 9407,
            9408, 9409, 9410, 9411, 9412, 9413, 9414, 9415, 9416, 9417, 9418, 9419, 9420, 9421, 9422, 9423, 9424, 9425,
            9426, 9427, 9428, 9429, 9430, 9431, 9432, 9433, 9445, 9446, 9447, 9448, 9449, 9450, 9451, 9452, 9453, 9454,
            9455, 9456, 9457, 9458, 9459, 9460, 9461, 9462, 9463, 9464, 9465, 9466, 9467, 9468, 9469, 9470, 9471, 9472,
            9473, 9474, 9475, 9476, 9477, 9478, 9479, 9480, 9481, 9482, 9483, 9496, 9497, 9498, 9499, 9500, 9501, 9502,
            9503, 9504, 9505, 9506, 9507, 9508, 9509, 9510, 9511, 9512, 9513, 9514, 9515, 9516, 9517, 9518, 9519, 9520,
            9521, 9522, 9523, 9524, 9525, 9526, 9527, 9528, 9529, 9530, 9531, 9532, 9533, 9534, 9535, 9536, 9537, 9604,
            9605, 9607, 9608, 9609, 9610, 9611, 9612, 9613, 9614, 9616, 9617, 9618, 9619, 9620, 9621, 9622, 9623, 9676,
            9677, 9678, 9679, 9680, 9681, 9682, 9683, 9684, 9685, 9686, 9687, 9688, 9689, 9690, 9691, 9692, 9693, 9694,
            9695, 9696, 9697, 9698, 9699, 9702, 9703, 9704, 9705, 9708, 9709, 9730, 9731, 9732, 9733, 9734, 9735, 9736,
            9737, 9738, 9739)
and m.sporttype <= 99

--- Deposit sportsbook --commission --group 2
INSERT INTO #result (transid)
SELECT bt.transid
FROM bettrans bt  with (nolock)
join match m with (nolock) on bt.matchid = m.matchid
join dbo.Dep_CustSettingMode dcm with (nolock) on dcm.custid = bt.custid
left join dbo.Dep_CustDiscountSetting_Member dcom with (nolock)  on dcom.custid = bt.custid and dcom.sporttype =1 and dcom.bettype=4
left join dbo.Dep_CustDiscountGroupSetting_Member gdcom with (nolock) on gdcom.agentid = bt.recommend and gdcom.sporttype =1 and gdcom.bettype=4
where 1 = case when dcm.isGroupedComm = 1 then 
				case when 	gdcom.playerdiscount <> bt.playerdiscount or
						 	gdcom.agentdiscount <> bt.discount or
						 	gdcom.masterdiscount <> bt.adiscount or
						 	gdcom.superdiscount <>  bt.sdiscount then 1 
				else 0 end 
				else
				case when bt.playerdiscount <> dcom.playerdiscount or
				          bt.discount <> dcom.agentdiscount or
				          bt.adiscount <> dcom.masterdiscount or
						  bt.sdiscount <> dcom.superdiscount then 1 
				else 0 end
				end
and bt.transdate between '20230330 04:00' and '20230330 04:20'
and bt.bettype in (4, 6, 10, 14, 16, 22, 24, 26, 30, 38, 126, 127, 133, 134, 135, 140, 141, 142, 143, 144, 145, 146, 147, 148,
            149, 150, 151, 152, 159, 160, 161, 162, 163, 164, 165, 166, 168, 169, 170, 171, 172, 173, 174, 175, 179,
            180, 181, 182, 186, 187, 188, 192, 193, 195, 196, 199, 200, 201, 202, 210, 211, 212, 213, 214, 215, 216,
            217, 221, 222, 223, 224, 225, 226, 227, 376, 384, 391, 392, 395, 396, 397, 398, 399, 405, 406, 407, 408,
            409, 410, 412, 413, 414, 416, 417, 418, 419, 420, 421, 422, 423, 424, 425, 426, 429, 431, 442, 445, 446,
            447, 448, 449, 450, 451, 452, 454, 455, 456, 457, 460, 467, 468, 469, 473, 474, 475, 476, 479, 481, 486,
            487, 493, 494, 495, 496, 601, 602, 608, 614, 618, 619, 620, 621, 622, 623, 624, 625, 626, 627, 628, 629,
            631, 632, 633, 634, 635, 636, 637, 638, 639, 640, 641, 642, 643, 644, 645, 646, 703, 711, 1302, 1317, 9088)		
and m.sporttype <= 99
AND NOT EXISTS (SELECT 1 FROM #result r WHERE r.transid = bt.transid)

--- Deposit sportsbook --commission --group 3
INSERT INTO #result (transid)
SELECT bt.transid
FROM bettrans bt  with (nolock)
join match m with (nolock) on bt.matchid = m.matchid
join dbo.Dep_CustSettingMode dcm with (nolock) on dcm.custid = bt.custid
left join dbo.Dep_CustDiscountSetting_Member dcom with (nolock)  on dcom.custid = bt.custid and dcom.sporttype =1 and dcom.bettype=5
left join dbo.Dep_CustDiscountGroupSetting_Member gdcom with (nolock) on gdcom.agentid = bt.recommend and gdcom.sporttype =1 and gdcom.bettype=5
where 1 = case when dcm.isGroupedComm = 1 then 
				case when 	gdcom.playerdiscount <> bt.playerdiscount or
						 	gdcom.agentdiscount <> bt.discount or
						 	gdcom.masterdiscount <> bt.adiscount or
						 	gdcom.superdiscount <>  bt.sdiscount then 1 
				else 0 end 
				else
				case when bt.playerdiscount <> dcom.playerdiscount or
				          bt.discount <> dcom.agentdiscount or
				          bt.adiscount <> dcom.masterdiscount or
						  bt.sdiscount <> dcom.superdiscount then 1 
				else 0 end
				end
and bt.transdate between '20230330 04:00' and '20230330 04:20'
and bt.bettype in (5, 15, 20, 21, 154, 167, 176, 177, 385, 430, 458, 459, 501, 502, 603, 604, 605, 606, 607, 612, 613, 617,
            630, 707, 712, 713, 714, 1301, 1311, 1324, 1332, 1333, 3901, 3903, 3909, 3912, 3914, 3916, 3918, 9001, 9006,
            9007,
            9011, 9015, 9016, 9017, 9021, 9022, 9023, 9027, 9031, 9032, 9033, 9037, 9038, 9039, 9043, 9044, 9045, 9049,
            9050, 9051, 9055, 9056, 9057, 9062, 9063, 9064, 9068, 9072, 9073, 9075, 9087, 9101, 9102, 9103, 9104, 9105,
            9106, 9107, 9108, 9109, 9110, 9111, 9112, 9113, 9114, 9115, 9122, 9124, 9125, 9130, 9132, 9133, 9135, 9138,
            9141, 9142, 9400, 9401, 9434, 9435, 9436, 9437, 9438, 9439, 9440, 9441, 9442, 9443, 9444, 9615, 9624, 9625,
            9626, 9627, 9628, 9629, 9630, 9631, 9632, 9633, 9634, 9635, 9662, 9663, 9664, 9665, 9666, 9667, 9710, 9711)	
and m.sporttype <= 99	
AND NOT EXISTS (SELECT 1 FROM #result r WHERE r.transid = bt.transid)

--- Deposit sportsbook --commission -- parlay
INSERT INTO #result (transid)
SELECT bt.transid
FROM bettrans bt  with (nolock)
join dbo.Dep_CustSettingMode dcm with (nolock) on dcm.custid = bt.custid
left join dbo.Dep_CustDiscountSetting_Member dcom with (nolock)  on dcom.custid = bt.custid and dcom.sporttype =1 and dcom.bettype=9 
left join dbo.Dep_CustDiscountGroupSetting_Member gdcom with (nolock) on gdcom.agentid = bt.recommend and gdcom.sporttype =1 and gdcom.bettype=9 
where 1 = case when dcm.isGroupedComm = 1 then 
				case when 	gdcom.playerdiscount <> bt.playerdiscount or
						 	gdcom.agentdiscount <> bt.discount or
						 	gdcom.masterdiscount <> bt.adiscount or
						 	gdcom.superdiscount <>  bt.sdiscount then 1 
				else 0 end 
				else
				case when bt.playerdiscount <> dcom.playerdiscount or
				          bt.discount <> dcom.agentdiscount or
				          bt.adiscount <> dcom.masterdiscount or
						  bt.sdiscount <> dcom.superdiscount then 1 
				else 0 end
				end
and bt.transdate between '20230330 04:00' and '20230330 04:20'
and bt.matchid = 29
AND NOT EXISTS (SELECT 1 FROM #result r WHERE r.transid = bt.transid)

--- Deposit sportsbook --PT -- single
INSERT INTO #result (transid)
SELECT bt.transid	
FROM bettrans bt  with (nolock)
join match m with (nolock) on bt.matchid = m.matchid
join dbo.Dep_CustSettingMode dcm with (nolock) on dcm.custid = bt.custid
left join dbo.Dep_CustPTSetting_Member dpt with (nolock)  on dpt.custid = bt.custid and dpt.sporttype =1 and dpt.bettype=1 and dpt.islive = 0
left join dbo.Dep_CustPTGroupSetting_Member gdpt with (nolock) on gdpt.agentid = bt.recommend and gdpt.sporttype =1 and gdpt.bettype=1 and gdpt.islive = 0
where 1 = case when dcm.isGroupedPT = 1 then 
				case when bt.apositiontaking <> ISNULL(gdpt.agentpt,0) /100 or
				          bt.mpositiontaking <> ISNULL(gdpt.masterpt,0) /100 or
						  bt.spositiontaking <> ISNULL(gdpt.superpt,0) /100 then 1 
				else 0 end 
				else
				case when bt.apositiontaking <> ISNULL(dpt.agentpt,0) /100 or
				          bt.mpositiontaking <> ISNULL(dpt.masterpt,0) /100 or
						  bt.spositiontaking <> ISNULL(dpt.superpt,0) /100 then 1 
				else 0 end
				end
and bt.transdate between '20230330 04:00' and '20230330 04:20'
and m.sporttype <= 99
AND NOT EXISTS (SELECT 1 FROM #result r WHERE r.transid = bt.transid)

--- Deposit sportsbook --PT -- parlay
INSERT INTO #result (transid)
SELECT bt.transid
FROM bettrans bt  with (nolock)
join dbo.Dep_CustSettingMode dcm with (nolock) on dcm.custid = bt.custid
left join dbo.Dep_CustPTSetting_Member dpt with (nolock)  on dpt.custid = bt.custid and dpt.sporttype =1 and dpt.bettype=1 and dpt.islive = 0
left join dbo.Dep_CustPTGroupSetting_Member gdpt with (nolock) on gdpt.agentid = bt.recommend and gdpt.sporttype =1 and gdpt.bettype=1 and gdpt.islive = 0
where 1 = case when dcm.isGroupedPT = 1 then 
				case when bt.apositiontaking <> ISNULL(gdpt.agentpt,0) /100 or
				          bt.mpositiontaking <> ISNULL(gdpt.masterpt,0) /100 or
						  bt.spositiontaking <> ISNULL(gdpt.superpt,0) /100 then 1 
				else 0 end 
				else
				case when bt.apositiontaking <> ISNULL(dpt.agentpt,0) /100 or
				          bt.mpositiontaking <> ISNULL(dpt.masterpt,0) /100 or
						  bt.spositiontaking <> ISNULL(dpt.superpt,0) /100 then 1 
				else 0 end
				end
and bt.transdate between '20230330 04:00' and '20230330 04:20'
and bt.matchid = 29
AND NOT EXISTS (SELECT 1 FROM #result r WHERE r.transid = bt.transid)
---------------
--number game - commission - single

INSERT INTO #result (transid)
SELECT bt.transid
FROM bettrans bt  with (nolock)
join match m with (nolock) on bt.matchid = m.matchid
join dbo.Dep_CustSettingMode dcm with (nolock) on dcm.custid = bt.custid
left join dbo.Dep_CustDiscountSetting_Member dcom with (nolock)  on dcom.custid = bt.custid and dcom.sporttype =161 and dcom.bettype=81 
left join dbo.Dep_CustDiscountGroupSetting_Member gdcom with (nolock) on gdcom.agentid = bt.recommend and gdcom.sporttype =161 and gdcom.bettype=81 
where 1 = case when dcm.isGroupedComm = 1 then 
				case when 	gdcom.playerdiscount <> bt.playerdiscount or
						 	gdcom.agentdiscount <> bt.discount or
						 	gdcom.masterdiscount <> bt.adiscount or
						 	gdcom.superdiscount <>  bt.sdiscount then 1 
				else 0 end 
				else
				case when bt.playerdiscount <> dcom.playerdiscount or
				          bt.discount <> dcom.agentdiscount or
				          bt.adiscount <> dcom.masterdiscount or
						  bt.sdiscount <> dcom.superdiscount then 1 
				else 0 end
				end
and bt.transdate between '20230330 04:00' and '20230330 04:20'
and m.sporttype in (161,164)
AND NOT EXISTS (SELECT 1 FROM #result r WHERE r.transid = bt.transid)

-- virtual sports - commission - single

INSERT INTO #result (transid)
SELECT bt.transid
FROM bettrans bt  with (nolock)
join match m with (nolock) on bt.matchid = m.matchid
join Sport_Bettype_Reference_Setting sbr with (nolock) on sbr.sporttype = m.sporttype and sbr.bettype = bt.bettype and sbr.islicensee = 1 and sbr.islive = bt.liveindicator and sbr.site = 'all'
join dbo.Dep_CustSettingMode dcm with (nolock) on dcm.custid = bt.custid
left join dbo.Dep_CustDiscountSetting_Member dcom with (nolock)  on dcom.custid = bt.custid and dcom.sporttype =sbr.sporttyperefcomm and dcom.bettype=sbr.bettyperefcomm
left join dbo.Dep_CustDiscountGroupSetting_Member gdcom with (nolock) on gdcom.agentid = bt.recommend and gdcom.sporttype =sbr.sporttyperefcomm and gdcom.bettype=sbr.bettyperefcomm 
where 1 = case when dcm.isGroupedComm = 1 then 
				case when 	gdcom.playerdiscount <> bt.playerdiscount or
						 	gdcom.agentdiscount <> bt.discount or
						 	gdcom.masterdiscount <> bt.adiscount or
						 	gdcom.superdiscount <>  bt.sdiscount then 1 
				else 0 end 
				else
				case when bt.playerdiscount <> dcom.playerdiscount or
				          bt.discount <> dcom.agentdiscount or
				          bt.adiscount <> dcom.masterdiscount or
						  bt.sdiscount <> dcom.superdiscount then 1 
				else 0 end
				end
and bt.transdate between '20230330 04:00' and '20230330 04:20'
and m.sporttype in  (180,186,190,191,192,193,194,195,196,197)
AND NOT EXISTS (SELECT 1 FROM #result r WHERE r.transid = bt.transid)

-- Bet radar parlay  - commission

INSERT INTO #result (transid)
SELECT bt.transid
FROM bettrans bt  with (nolock)
join dbo.Dep_CustSettingMode dcm with (nolock) on dcm.custid = bt.custid
left join dbo.Dep_CustDiscountSetting_Member dcom with (nolock)  on dcom.custid = bt.custid and dcom.sporttype =190 and dcom.bettype=2701
left join dbo.Dep_CustDiscountGroupSetting_Member gdcom with (nolock) on gdcom.agentid = bt.recommend and gdcom.sporttype =190 and gdcom.bettype=2701
where 1 = case when dcm.isGroupedComm = 1 then 
				case when 	gdcom.playerdiscount <> bt.playerdiscount or
						 	gdcom.agentdiscount <> bt.discount or
						 	gdcom.masterdiscount <> bt.adiscount or
						 	gdcom.superdiscount <>  bt.sdiscount then 1 
				else 0 end 
				else
				case when bt.playerdiscount <> dcom.playerdiscount or
				          bt.discount <> dcom.agentdiscount or
				          bt.adiscount <> dcom.masterdiscount or
						  bt.sdiscount <> dcom.superdiscount then 1 
				else 0 end
				end
and bt.transdate between '20230330 04:00' and '20230330 04:20'
and bt.bettype = 2799
AND NOT EXISTS (SELECT 1 FROM #result r WHERE r.transid = bt.transid)

-------------------------PT
--number game - PT - single

INSERT INTO #result (transid)
SELECT bt.transid
FROM bettrans bt  with (nolock)
join match m with (nolock) on bt.matchid = m.matchid
join dbo.Dep_CustSettingMode dcm with (nolock) on dcm.custid = bt.custid
left join dbo.Dep_CustPTSetting_Member dpt with (nolock)  on dpt.custid = bt.custid and dpt.sporttype =161 and dpt.bettype=81 and dpt.islive = 0
left join dbo.Dep_CustPTGroupSetting_Member gdpt with (nolock) on gdpt.agentid = bt.recommend and gdpt.sporttype =161 and gdpt.bettype=81 and gdpt.islive = 0
where 1 = case when dcm.isGroupedPT = 1 then 
				case when bt.apositiontaking <> ISNULL(gdpt.agentpt,0) /100 or
				          bt.mpositiontaking <> ISNULL(gdpt.masterpt,0) /100 or
						  bt.spositiontaking <> ISNULL(gdpt.superpt,0) /100 then 1 
				else 0 end 
				else
				case when bt.apositiontaking <> ISNULL(dpt.agentpt,0) /100 or
				          bt.mpositiontaking <> ISNULL(dpt.masterpt,0) /100 or
						  bt.spositiontaking <> ISNULL(dpt.superpt,0) /100 then 1 
				else 0 end
				end
and bt.transdate between '20230330 04:00' and '20230330 04:20'
and m.sporttype in (161,164)
AND NOT EXISTS (SELECT 1 FROM #result r WHERE r.transid = bt.transid)

-- betradar & inspire - PT

INSERT INTO #result (transid)
SELECT bt.transid
FROM bettrans bt  with (nolock)
join match m with (nolock) on bt.matchid = m.matchid
join Sport_Bettype_Reference_Setting sbr with (nolock) on sbr.sporttype = m.sporttype and sbr.bettype = bt.bettype and sbr.islicensee = 1 and sbr.islive = bt.liveindicator and sbr.site = 'all'
join dbo.Dep_CustSettingMode dcm with (nolock) on dcm.custid = bt.custid
left join dbo.Dep_CustPTSetting_Member dpt with (nolock)  on dpt.custid = bt.custid and dpt.sporttype =sbr.sporttyperefpt and dpt.bettype=sbr.bettyperefpt and dpt.islive = 0
left join dbo.Dep_CustPTGroupSetting_Member gdpt with (nolock) on gdpt.agentid = bt.recommend and gdpt.sporttype =sbr.sporttyperefpt and gdpt.bettype=sbr.bettyperefpt and gdpt.islive = 0
where 1 = case when dcm.isGroupedPT = 1 then 
				case when bt.apositiontaking <> ISNULL(gdpt.agentpt,0) /100 or
				          bt.mpositiontaking <> ISNULL(gdpt.masterpt,0) /100 or
						  bt.spositiontaking <> ISNULL(gdpt.superpt,0) /100 then 1 
				else 0 end 
				else
				case when bt.apositiontaking <> ISNULL(dpt.agentpt,0) /100 or
				          bt.mpositiontaking <> ISNULL(dpt.masterpt,0) /100 or
						  bt.spositiontaking <> ISNULL(dpt.superpt,0) /100 then 1 
				else 0 end
				end
and bt.transdate between '20230330 04:00' and '20230330 04:20'
and m.sporttype in (180,186,190,191,192,193,194,195,196,197) 
AND NOT EXISTS (SELECT 1 FROM #result r WHERE r.transid = bt.transid)

-- betradar parlay - PT

INSERT INTO #result (transid)					
select transid
from bettrans bt with (nolock)																
join Sport_Bettype_Reference_Setting sbr with (nolock) on sbr.sporttype = bt.oddsid and sbr.bettype = bt.bettype and sbr.islicensee = 1 and sbr.islive = bt.liveindicator and sbr.site = 'all'
join dbo.Dep_CustSettingMode dcm with (nolock) on dcm.custid = bt.custid
left join dbo.Dep_CustPTSetting_Member dpt with (nolock)  on dpt.custid = bt.custid and dpt.sporttype =sbr.sporttyperefpt and dpt.bettype=sbr.bettyperefpt and dpt.islive = 0
left join dbo.Dep_CustPTGroupSetting_Member gdpt with (nolock) on gdpt.agentid = bt.recommend and gdpt.sporttype =sbr.sporttyperefpt and gdpt.bettype=sbr.bettyperefpt and gdpt.islive = 0				
where  1 = case when dcm.isGroupedPT = 1 then						
				case when bt.apositiontaking <> ISNULL(gdpt.agentpt,0) /100 or		
						  bt.mpositiontaking <> ISNULL(gdpt.masterpt,0) /100 or		
						  bt.spositiontaking <> ISNULL(gdpt.superpt,0) /100 then 1
				else 0 end		
				else		
				case when bt.apositiontaking <> ISNULL(dpt.agentpt,0) /100 or		
						  bt.mpositiontaking <> ISNULL(dpt.masterpt,0) /100 or		
						  bt.spositiontaking <> ISNULL(dpt.superpt,0) /100 then 1
				else 0 end		
				end		
			
and bt.transdate between '20230330 04:00' and '20230330 04:20'		
and bt.bettype = 2799	
AND NOT EXISTS (SELECT 1 FROM #result r WHERE r.transid = bt.transid)

--------------
SELECT DISTINCT tmp_old.*, tmp_new.*
FROM #result c
	cross apply (select TOP 1 a.site , s.username super , m.username master, a.username agent, b.username,b.custid,b.transid, matchid, bettype, sitedbgroupid
					--status
					, b.currencyname,status AS status_old
					--winlost ammout
					,WinLost AS WinLost_old,aWinLost AS aWinLost_old,mWinLost AS mWinLost_old,sWinLost AS sWinLost_old 
					-- commission amount
					,PlayerComm AS PlayerComm_old,Comm AS Comm_old,aComm AS aComm_old,sComm AS sComm_old
					--PT setting value
					,apositiontaking AS apositiontaking_old,mpositiontaking AS mpositiontaking_old,spositiontaking AS spositiontaking_old
					--comm setting value
					,playerdiscount AS playerdiscount_old,discount AS discount_old,adiscount AS adiscount_old,sdiscount AS sdiscount_old
				from bettrans b with (nolock)
				join vw_customer s with (nolock) on s.custID = b.srecommend
				join vw_customer m with (nolock) on m.custId = b.mrecommend
				join vw_customer a with (nolock) on a.custId = b.recommend
				where b.transid = c.transid) AS tmp_old
	cross apply (select TOP 1
					--status
					status AS status_new
					--winlost ammout
					,WinLost AS WinLost_new,aWinLost AS aWinLost_new,mWinLost AS mWinLost_new,sWinLost AS sWinLost_new 
					-- commission amount
					,PlayerComm AS PlayerComm_new,Comm AS Comm_new,aComm AS aComm_new,sComm AS sComm_new
					--PT setting value
					,apositiontaking AS apositiontaking_new,mpositiontaking AS mpositiontaking_new,spositiontaking AS spositiontaking_new
					--comm setting value
					,playerdiscount AS playerdiscount_new,discount AS discount_new,adiscount AS adiscount_new,sdiscount AS sdiscount_new
				from [dbtranskbt].bodb02.dbo.bettrans b with (nolock)
				where b.transid = c.transid) AS tmp_new


/*
drop table #result
*/