"""Render original text and logo over a blank social card; reuse approved editorial art."""
from PIL import Image,ImageDraw
from render import ROOT,OUT,art,mark,text,BG,INK
im=Image.new('RGB',(1200,630),BG);art(im,(600,120,570,430));d=ImageDraw.Draw(im)
mark(d,65,48,6);text(d,(126,44),'Reeeead',32)
text(d,(65,175),'Eyes: finished.',59)
text(d,(65,250),'Brain: who are you?',49)
text(d,(65,370),'Read a little easier.',33,'#6d8060')
text(d,(65,455),'An open-source reading companion for Mac.',20)
text(d,(65,546),'SELECTED-TEXT SPEECH  /  A TWO-CLICK READING BAND',13,'#73776e')
im.save(ROOT/'marketing/assets/launch-cover.jpg',quality=91)
im.save(ROOT/'local/site-release/dist/assets/social-card.jpg',quality=91)
print('Created 1200 × 630 social card')
