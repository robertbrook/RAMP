function toggle_answer(num){
  answer=document.getElementById("answer" + num);
  if (answer.style.display == "block") {
    answer.style.display="none";
  } else {
    answer.style.display="block";
  }
}