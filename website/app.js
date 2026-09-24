document.documentElement.classList.add("js");

const body = document.body;
const header = document.querySelector(".site-header");
const menuToggle = document.querySelector(".menu-toggle");
const navigation = document.querySelector(".main-nav");
const faqButtons = document.querySelectorAll(".faq-item button");
const leadForm = document.querySelector("#lead-form");
const toast = document.querySelector("#toast");

document.querySelector("#current-year").textContent = new Date().getFullYear();

function updateHeader() {
  header.classList.toggle("scrolled", window.scrollY > 12);
}

updateHeader();
window.addEventListener("scroll", updateHeader, { passive: true });

function closeMenu() {
  navigation.classList.remove("open");
  menuToggle.setAttribute("aria-expanded", "false");
  menuToggle.setAttribute("aria-label", "فتح القائمة");
  body.classList.remove("menu-open");
}

menuToggle.addEventListener("click", () => {
  const shouldOpen = menuToggle.getAttribute("aria-expanded") !== "true";
  navigation.classList.toggle("open", shouldOpen);
  menuToggle.setAttribute("aria-expanded", String(shouldOpen));
  menuToggle.setAttribute("aria-label", shouldOpen ? "إغلاق القائمة" : "فتح القائمة");
  body.classList.toggle("menu-open", shouldOpen);
});

navigation.querySelectorAll("a").forEach((link) => link.addEventListener("click", closeMenu));

document.addEventListener("click", (event) => {
  if (
    navigation.classList.contains("open") &&
    !navigation.contains(event.target) &&
    !menuToggle.contains(event.target)
  ) {
    closeMenu();
  }
});

document.addEventListener("keydown", (event) => {
  if (event.key === "Escape" && navigation.classList.contains("open")) {
    closeMenu();
    menuToggle.focus();
  }
});

faqButtons.forEach((button) => {
  button.addEventListener("click", () => {
    const item = button.closest(".faq-item");
    const isOpen = item.classList.contains("open");

    document.querySelectorAll(".faq-item").forEach((faqItem) => {
      faqItem.classList.remove("open");
      faqItem.querySelector("button").setAttribute("aria-expanded", "false");
    });

    if (!isOpen) {
      item.classList.add("open");
      button.setAttribute("aria-expanded", "true");
    }
  });
});

function showToast(message) {
  toast.textContent = message;
  toast.classList.add("show");
  window.clearTimeout(showToast.timeoutId);
  showToast.timeoutId = window.setTimeout(() => toast.classList.remove("show"), 3200);
}

function whatsappUrl(message) {
  const number = body.dataset.whatsapp.trim().replace(/\D/g, "");
  const destination = number ? `https://wa.me/${number}` : "https://wa.me/";
  return `${destination}?text=${encodeURIComponent(message)}`;
}

leadForm.addEventListener("submit", (event) => {
  event.preventDefault();

  if (!leadForm.reportValidity()) return;

  const data = new FormData(leadForm);
  const name = data.get("name").trim();
  const phone = data.get("phone").trim();
  const business = data.get("business").trim() || "غير محدد";
  const need = data.get("need");
  const message = [
    "أهلًا، عايز أعرف تفاصيل أكتر عن نظام حِسبة.",
    "",
    `الاسم: ${name}`,
    `رقم التواصل: ${phone}`,
    `المحل/الشركة: ${business}`,
    `الاحتياج الأساسي: ${need}`,
  ].join("\n");

  const hasSalesNumber = Boolean(body.dataset.whatsapp.trim());
  if (!hasSalesNumber) {
    showToast("تم تجهيز الرسالة — اختر محادثة واتساب لإرسالها.");
  }

  window.open(whatsappUrl(message), "_blank", "noopener,noreferrer");
});

const revealElements = document.querySelectorAll(".reveal");

if ("IntersectionObserver" in window) {
  const observer = new IntersectionObserver(
    (entries) => {
      entries.forEach((entry) => {
        if (entry.isIntersecting) {
          entry.target.classList.add("visible");
          observer.unobserve(entry.target);
        }
      });
    },
    { threshold: 0.1, rootMargin: "0px 0px -35px" },
  );

  revealElements.forEach((element) => observer.observe(element));
} else {
  revealElements.forEach((element) => element.classList.add("visible"));
}
