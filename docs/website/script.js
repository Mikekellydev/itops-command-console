// ITOps Command Console - Frontend Enhancements

// ==============================
// Header Shrink on Scroll
// ==============================

const header = document.querySelector("header");

window.addEventListener("scroll", () => {
  if (window.scrollY > 40) {
    header.classList.add("shrink");
  } else {
    header.classList.remove("shrink");
  }
});


// ==============================
// Fade-In Sections on Scroll
// ==============================

const sections = document.querySelectorAll("section");

const observer = new IntersectionObserver(
  (entries) => {
    entries.forEach(entry => {
      if (entry.isIntersecting) {
        entry.target.classList.add("visible");
      }
    });
  },
  { threshold: 0.15 }
);

sections.forEach(section => {
  section.classList.add("hidden");
  observer.observe(section);
});


// ==============================
// Copy Code Block Button
// ==============================

document.querySelectorAll("pre").forEach(block => {
  const button = document.createElement("button");
  button.innerText = "Copy";
  button.className = "copy-btn";

  block.style.position = "relative";
  block.appendChild(button);

  button.addEventListener("click", () => {
    navigator.clipboard.writeText(block.innerText);
    button.innerText = "Copied";
    setTimeout(() => button.innerText = "Copy", 1500);
  });
});


// ==============================
// Dark / Light Theme Toggle
// ==============================

const toggle = document.createElement("button");
toggle.innerText = "Toggle Theme";
toggle.className = "theme-toggle";
document.body.appendChild(toggle);

const currentTheme = localStorage.getItem("theme");
if (currentTheme === "light") {
  document.body.classList.add("light");
}

toggle.addEventListener("click", () => {
  document.body.classList.toggle("light");

  if (document.body.classList.contains("light")) {
    localStorage.setItem("theme", "light");
  } else {
    localStorage.setItem("theme", "dark");
  }
});
